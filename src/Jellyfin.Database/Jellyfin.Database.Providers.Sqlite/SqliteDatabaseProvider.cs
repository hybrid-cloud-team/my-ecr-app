using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Database.Implementations;
using Jellyfin.Database.Implementations.DbConfiguration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Database.Providers.Sqlite;

/// <summary>
/// [수정 사항] 이름은 SqliteDatabaseProvider이지만, 내부 로직을 AWS RDS(MySQL) 접속으로 강제 전환합니다.
/// </summary>
[JellyfinDatabaseProviderKey("Jellyfin-SQLite")]
public sealed class SqliteDatabaseProvider : IJellyfinDatabaseProvider
{
    private readonly ILogger<SqliteDatabaseProvider> _logger;

    public SqliteDatabaseProvider(ILogger<SqliteDatabaseProvider> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc/>
    public IDbContextFactory<JellyfinDbContext>? DbContextFactory { get; set; }

    /// <inheritdoc/>
    public void Initialise(DbContextOptionsBuilder options, DatabaseConfigurationOptions databaseConfiguration)
    {
        // [수정 사항] 1. 환경변수에서 RDS 접속 정보를 읽어옵니다.
        var dbHost = Environment.GetEnvironmentVariable("DB_HOST");
        var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "jellyfin";
        var dbUser = Environment.GetEnvironmentVariable("DB_USER");
        var dbPass = Environment.GetEnvironmentVariable("DB_PASSWORD");

        // [수정 사항] 2. MySQL용 연결 문자열(Connection String) 생성
        var connectionString = $"Server={dbHost};Port=3306;Database={dbName};User={dbUser};Password={dbPass};CharSet=utf8mb4;";

        _logger.LogInformation("Connecting to RDS MySQL: {Host}", dbHost);

        // [수정 사항] 3. UseSqlite 대신 UseMySql을 사용하여 RDS에 접속합니다.
        options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString),
            mySqlOptions => 
            {
                // 마이그레이션 위치를 지정합니다.
                mySqlOptions.MigrationsAssembly("Jellyfin.Server");
                // RDS 연결 재시도 로직 추가
                mySqlOptions.EnableRetryOnFailure(5, TimeSpan.FromSeconds(30), null);
            })
            .ConfigureWarnings(warnings =>
                warnings.Ignore(RelationalEventId.NonTransactionalMigrationOperationWarning));
    }

    /// <inheritdoc/>
    public void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.SetDefaultDateTimeKind(DateTimeKind.Utc);
    }

    /// <inheritdoc/>
    public void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        // MySQL에서는 필요 없는 컨벤션일 수 있으나 인터페이스 유지를 위해 남겨둡니다.
    }

    /// <inheritdoc/>
    public async Task RunScheduledOptimisation(CancellationToken cancellationToken)
    {
        // MySQL 전용 최적화 명령어로 대체 가능 (여기서는 로그만 남김)
        _logger.LogInformation("RDS MySQL optimization task started.");
        await Task.CompletedTask;
    }

    /// <inheritdoc/>
    public async Task RunShutdownTask(CancellationToken cancellationToken)
    {
        await Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task<string> MigrationBackupFast(CancellationToken cancellationToken)
    {
        // RDS는 자체 백업 기능을 사용하므로 더미 값을 반환합니다.
        return Task.FromResult("RDS_BACKUP");
    }

    /// <inheritdoc />
    public Task RestoreBackupFast(string key, CancellationToken cancellationToken) => Task.CompletedTask;

    /// <inheritdoc />
    public Task DeleteBackup(string key) => Task.CompletedTask;

    /// <inheritdoc/>
    public async Task PurgeDatabase(JellyfinDbContext dbContext, IEnumerable<string>? tableNames)
    {
        if (tableNames == null) return;

        foreach (var tableName in tableNames)
        {
            var query = $"DELETE FROM `{tableName}`;";
            await dbContext.Database.ExecuteSqlRawAsync(query).ConfigureAwait(false);
        }
    }
}
