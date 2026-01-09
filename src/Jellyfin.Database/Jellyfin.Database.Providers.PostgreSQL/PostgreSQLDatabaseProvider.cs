using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Database.Implementations;
using Jellyfin.Database.Implementations.DbConfiguration;
using MediaBrowser.Common.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace Jellyfin.Database.Providers.PostgreSQL;

/// <summary>
/// Configures jellyfin to use a PostgreSQL database.
/// </summary>
[JellyfinDatabaseProviderKey("Jellyfin-PostgreSQL")]
public sealed class PostgreSQLDatabaseProvider : IJellyfinDatabaseProvider
{
    private readonly IApplicationPaths _applicationPaths;
    private readonly ILogger<PostgreSQLDatabaseProvider> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="PostgreSQLDatabaseProvider"/> class.
    /// </summary>
    /// <param name="applicationPaths">Service to construct the fallback when the old data path configuration is used.</param>
    /// <param name="logger">A logger.</param>
    public PostgreSQLDatabaseProvider(IApplicationPaths applicationPaths, ILogger<PostgreSQLDatabaseProvider> logger)
    {
        _applicationPaths = applicationPaths;
        _logger = logger;
    }

    /// <inheritdoc/>
    public IDbContextFactory<JellyfinDbContext>? DbContextFactory { get; set; }

    /// <inheritdoc/>
    public void Initialise(DbContextOptionsBuilder options, DatabaseConfigurationOptions databaseConfiguration)
    {
        static T? GetOption<T>(ICollection<CustomDatabaseOption>? options, string key, Func<string, T> converter, Func<T>? defaultValue = null)
        {
            if (options is null)
            {
                return defaultValue is not null ? defaultValue() : default;
            }

            var value = options.FirstOrDefault(e => e.Key.Equals(key, StringComparison.OrdinalIgnoreCase));
            if (value is null)
            {
                return defaultValue is not null ? defaultValue() : default;
            }

            return converter(value.Value);
        }

        var customOptions = databaseConfiguration.CustomProviderOptions?.Options;

        // PostgreSQL connection string 구성
        var connectionStringBuilder = new NpgsqlConnectionStringBuilder
        {
            Host = GetOption(customOptions, "Host", e => e, () => "localhost")!,
            Port = GetOption(customOptions, "Port", int.Parse, () => 5432),
            Database = GetOption(customOptions, "Database", e => e, () => "jellyfin")!,
            Username = GetOption(customOptions, "Username", e => e, () => "jellyfin")!,
            Password = GetOption(customOptions, "Password", e => e, () => string.Empty)!,
            CommandTimeout = GetOption(customOptions, "CommandTimeout", int.Parse, () => 30),
            Pooling = GetOption(customOptions, "Pooling", e => e.Equals(bool.TrueString, StringComparison.OrdinalIgnoreCase), () => true),
            MinPoolSize = GetOption(customOptions, "MinPoolSize", int.Parse, () => 0),
            MaxPoolSize = GetOption(customOptions, "MaxPoolSize", int.Parse, () => 100),
            Timeout = GetOption(customOptions, "Timeout", int.Parse, () => 30)
        };

        // SSL 모드 설정 (기본값: Prefer)
        var sslMode = GetOption(customOptions, "SslMode", e => Enum.Parse<Npgsql.SslMode>(e, true), () => Npgsql.SslMode.Prefer);
        connectionStringBuilder.SslMode = sslMode;

        // Trust Server Certificate 옵션 (RDS 등에서 사용)
        var trustServerCertificate = GetOption(customOptions, "TrustServerCertificate", e => e.Equals(bool.TrueString, StringComparison.OrdinalIgnoreCase), () => false);
        if (trustServerCertificate)
        {
            connectionStringBuilder.TrustServerCertificate = true;
        }

        var connectionString = connectionStringBuilder.ToString();

        // 연결 문자열에서 비밀번호는 로그에 출력하지 않음
        var safeConnectionString = connectionStringBuilder.ToString().Replace(connectionStringBuilder.Password, "***");
        _logger.LogInformation("PostgreSQL connection string: {ConnectionString}", safeConnectionString);

        options
            .UseNpgsql(
                connectionString,
                npgsqlOptions => npgsqlOptions.MigrationsAssembly(GetType().Assembly))
            .ConfigureWarnings(warnings =>
                warnings.Ignore(RelationalEventId.NonTransactionalMigrationOperationWarning));

        var enableSensitiveDataLogging = GetOption(customOptions, "EnableSensitiveDataLogging", e => e.Equals(bool.TrueString, StringComparison.OrdinalIgnoreCase), () => false);
        if (enableSensitiveDataLogging)
        {
            options.EnableSensitiveDataLogging(enableSensitiveDataLogging);
            _logger.LogInformation("EnableSensitiveDataLogging is enabled on PostgreSQL connection");
        }
    }

    /// <inheritdoc/>
    public async Task RunScheduledOptimisation(CancellationToken cancellationToken)
    {
        var context = await DbContextFactory!.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        await using (context.ConfigureAwait(false))
        {
            // PostgreSQL VACUUM ANALYZE 실행
            await context.Database.ExecuteSqlRawAsync("VACUUM ANALYZE", cancellationToken).ConfigureAwait(false);
            _logger.LogInformation("PostgreSQL database optimized successfully!");
        }
    }

    /// <inheritdoc/>
    public void OnModelCreating(ModelBuilder modelBuilder)
    {
        ModelBuilderExtensions.SetDefaultDateTimeKind(modelBuilder, DateTimeKind.Utc);
    }

    /// <inheritdoc/>
    public Task RunShutdownTask(CancellationToken cancellationToken)
    {
        // PostgreSQL은 연결 풀을 자동으로 관리하므로 특별한 종료 작업이 필요 없음
        return Task.CompletedTask;
    }

    /// <inheritdoc/>
    public void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        // PostgreSQL 특화 컨벤션이 필요한 경우 여기에 추가
    }

    /// <inheritdoc />
    public Task<string> MigrationBackupFast(CancellationToken cancellationToken)
    {
        // PostgreSQL 백업은 pg_dump를 사용해야 하므로, 여기서는 키만 반환
        // 실제 백업은 외부 도구를 사용하는 것을 권장
        var key = DateTime.UtcNow.ToString("yyyyMMddhhmmss", CultureInfo.InvariantCulture);
        _logger.LogWarning("PostgreSQL fast backup is not implemented. Please use pg_dump for backups. Backup key: {Key}", key);
        return Task.FromResult(key);
    }

    /// <inheritdoc />
    public Task RestoreBackupFast(string key, CancellationToken cancellationToken)
    {
        _logger.LogWarning("PostgreSQL fast restore is not implemented. Please use pg_restore for restores. Backup key: {Key}", key);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task DeleteBackup(string key)
    {
        _logger.LogWarning("PostgreSQL backup deletion is not implemented. Backup key: {Key}", key);
        return Task.CompletedTask;
    }

    /// <inheritdoc/>
    public async Task PurgeDatabase(JellyfinDbContext dbContext, IEnumerable<string>? tableNames)
    {
        if (tableNames is null)
        {
            // 모든 테이블 삭제
            await dbContext.Database.ExecuteSqlRawAsync("TRUNCATE TABLE \"__EFMigrationsHistory\" RESTART IDENTITY CASCADE", CancellationToken.None).ConfigureAwait(false);
            return;
        }

        var deleteQueries = new List<string>();
        foreach (var tableName in tableNames)
        {
            deleteQueries.Add($"TRUNCATE TABLE \"{tableName}\" RESTART IDENTITY CASCADE;");
        }

        var deleteAllQuery = string.Join('\n', deleteQueries);
        await dbContext.Database.ExecuteSqlRawAsync(deleteAllQuery).ConfigureAwait(false);
    }
}
