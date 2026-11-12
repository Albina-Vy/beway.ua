// BEWAY API — мінімальний каркас.
// Свідомо не містить БД, автентифікації та прийому персональних даних:
// ці модулі додаються лише після правового й технічного проєктування (ТЗ §20).

var builder = WebApplication.CreateBuilder(args);

// Дозволені джерела беремо з конфігурації, а не з коду,
// щоб продакшн-домен не потрапляв у репозиторій.
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins").Get<string[]>() ?? new[] { "http://localhost:4321" };

builder.Services.AddCors(options =>
    options.AddPolicy("frontend", policy => policy
        .WithOrigins(allowedOrigins)
        .AllowAnyHeader()
        .AllowAnyMethod()));

builder.Services.AddHealthChecks();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseCors("frontend");

app.MapGet("/api/health", () => Results.Ok(new
{
    service = "BEWAY.Api",
    status = "ok",
    version = "0.2.0"
}));

// Чесний стан пілоту. Фронтенд поки не залежить від цього ендпоїнта,
// але саме звідси він читатиме доступність заявок, коли вона зʼявиться.
app.MapGet("/api/status", () => Results.Ok(new
{
    pilot = "preparing",
    applicationsOpen = false,
    acceptsPersonalData = false
}));

app.Run();
