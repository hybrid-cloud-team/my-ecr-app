using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Logging.Abstractions;

namespace Jellyfin.Database.Providers.Sqlite.Migrations
{
    public class SqliteDesignTimeJellyfinDbFactory : IDesignTimeDbContextFactory<JellyfinDbContext>
    {
        public JellyfinDbContext CreateDbContext(string[] args)
        {
            // 아까 우리가 생성자를 바꿨기 때문에, 여기서도 인자를 맞춰줘야 합니다.
            return new JellyfinDbContext(new SqliteDatabaseProvider(NullLogger<SqliteDatabaseProvider>.Instance));
        }
    }
}
