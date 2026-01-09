using Jellyfin.Database.Implementations;
using Jellyfin.Database.Implementations.Locking;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Logging.Abstractions;

namespace Jellyfin.Database.Providers.PostgreSQL.Migrations;

/// <summary>
/// The design time factory for <see cref="JellyfinDbContext"/>.
/// This is only used for the creation of migrations and not during runtime.
/// </summary>
internal sealed class PostgreSQLDesignTimeJellyfinDbFactory : IDesignTimeDbContextFactory<JellyfinDbContext>
{
    public JellyfinDbContext CreateDbContext(string[] args)
    {
        // 환경 변수에서 연결 문자열을 가져오거나 기본값 사용
        var connectionString = Environment.GetEnvironmentVariable("POSTGRESQL_CONNECTION_STRING")
            ?? "Host=localhost;Port=5432;Database=jellyfin;Username=jellyfin;Password=jellyfin";

        var optionsBuilder = new DbContextOptionsBuilder<JellyfinDbContext>();
        optionsBuilder.UseNpgsql(connectionString, f => f.MigrationsAssembly(GetType().Assembly));

        return new JellyfinDbContext(
            optionsBuilder.Options,
            NullLogger<JellyfinDbContext>.Instance,
            new PostgreSQLDatabaseProvider(null!, NullLogger<PostgreSQLDatabaseProvider>.Instance),
            new NoLockBehavior(NullLogger<NoLockBehavior>.Instance));
    }
}
