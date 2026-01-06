using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Logging.Abstractions;
using Jellyfin.Database.Implementations; // <--- 이 줄이 핵심입니다!

namespace Jellyfin.Database.Providers.Sqlite.Migrations
{
    public class SqliteDesignTimeJellyfinDbFactory : IDesignTimeDbContextFactory<JellyfinDbContext>
    {
        public JellyfinDbContext CreateDbContext(string[] args)
        {
            // 인자 값으로 NullLogger를 전달하여 생성자 규칙을 맞춥니다.
            return new JellyfinDbContext(new SqliteDatabaseProvider(NullLogger<SqliteDatabaseProvider>.Instance));
        }
    }
}
