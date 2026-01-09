using System;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace Jellyfin.Database.Providers.PostgreSQL.ValueConverters;

/// <summary>
/// Value converter for DateTime with specific DateTimeKind.
/// </summary>
public class DateTimeKindValueConverter : ValueConverter<DateTime, DateTime>
{
    /// <summary>
    /// Initializes a new instance of the <see cref="DateTimeKindValueConverter"/> class.
    /// </summary>
    /// <param name="kind">The DateTimeKind to convert to.</param>
    public DateTimeKindValueConverter(DateTimeKind kind)
        : base(
            v => v.Kind == kind ? v : DateTime.SpecifyKind(v, kind),
            v => v.Kind == kind ? v : DateTime.SpecifyKind(v, kind))
    {
    }
}
