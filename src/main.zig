const std = @import("std");
const zig_invaders = @import("zig_invaders");
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
const Config = @import("./Config.zig"); // Import the config

const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.width and
            other.x < self.x + self.width and
            self.y < other.y + other.height and
            other.y < self.x + self.height;
    }

    pub fn draw(self: Rect, color: rl.Color) void {
        rl.drawRectangle(@intFromFloat(self.x), @intFromFloat(self.y), @intFromFloat(self.width), @intFromFloat(self.height), color);
    }
};

const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) @This() {
        return .{
            .x = x,
            .y = y,
        };
    }

    pub fn scale(self: @This(), a: f32) @This() {
        return .{
            .x = self.x * a,
            .y = self.y * a,
        };
    }

    pub fn normalised(self: @This()) @This() {
        const length = @sqrt(self.x * self.x + self.y * self.y);
        if (length > 0) {
            return .{
                .x = self.x / length,
                .y = self.y / length,
            };
        }
        return .{
            .x = 0,
            .y = 0,
        };
    }
};

const Player = struct {
    width: f32,
    height: f32,
    pos_x: f32,
    pos_y: f32,
    speed: f32,
    game_state_p: *GameState,
    // bullet_pool_p: *BulletPool,

    pub fn initStateless(playerConfig: Config.Player) @This() {
        return .{
            .width = playerConfig.width,
            .height = playerConfig.height,
            .pos_x = playerConfig.startX,
            .pos_y = playerConfig.startY,
            .speed = playerConfig.speed,
            .game_state_p = undefined,
            // .bullet_pool_p = undefined,
        };
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.*.game_state_p = game_state_p;
    }

    // pub fn attach_bullet_pool(self: *@This(), bullet_pool_p: *BulletPool) void {
    //     self.bullet_pool_p = bullet_pool_p;
    // }

    pub fn draw(self: @This()) void {
        self.rect().draw(rl.Color.blue);
    }

    pub fn rect(self: @This()) Rect {
        return Rect{
            .height = self.height,
            .width = self.width,
            .x = self.pos_x,
            .y = self.pos_y,
        };
    }

    pub fn update(self: *@This()) void {
        // movement
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            self.pos_x -= self.speed;
        }
        if (rl.isKeyDown(rl.KeyboardKey.right)) {
            self.pos_x += self.speed;
        }
        self.pos_x = std.math.clamp(self.pos_x, 0, @as(f32, @floatFromInt(self.game_state_p.*.game_config.screenWidth)) - self.width);

        // shooting
        // TODO: Check if minimum time has passed since last shot
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            // Let bullet pool know where to fire from
            const bullet_start_x = self.pos_x + (self.width / 2.0);
            const bullet_start_y = self.pos_y;
            const direction = Vec2.init(0.0, -1.0);
            self.game_state_p.fire_bullet(bullet_start_x, bullet_start_y, direction);
        }
    }
};

const BulletHandler = struct {
    // bullets: []Bullet,
    // allocator: Allocator,
    // game_state_p: *GameState,

    // pub fn initStateless(allocator: Allocator, bullet_pool_config: Config.BulletPool) !@This() {
    //     const bullets = (try allocator.alloc(Bullet, bullet_pool_config.max_bullets));

    //     // cannot iterate over dynamically allocated array slike this:
    //     for (bullets) |*bullet| {
    //         bullet.* = Bullet.initStateless(bullet_pool_config.bullet_config);
    //     }

    //     // instead we can use a loop to initialize each bullet
    //     // for (0..bullets.len) |i| {
    //     //     bullets[i].* = Bullet.initStateless(bullet_pool_config.bullet_config);
    //     // }

    //     return .{
    //         .bullets = bullets,
    //         .allocator = allocator,
    //         .game_state_p = undefined,
    //     };
    // }

    // pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
    //     self.game_state_p = game_state_p;
    //     for (self.bullets) |*bullet| {
    //         bullet.attachGameState(game_state_p);
    //     }
    // }

    pub fn draw(bullets: []Bullet) void {
        for (bullets) |bullet| {
            bullet.draw();
        }
    }

    pub fn update(bullets: *[]Bullet) void {
        for (bullets.*) |*bullet| {
            bullet.update();
        }
    }

    pub fn fire_bullet(bullets: *[]Bullet, emitter_x: f32, emitter_y: f32, direction: Vec2) void {
        for (bullets.*) |*bullet| {
            if (!bullet.is_active) {
                bullet.fire(emitter_x, emitter_y, direction);
                break;
            }
        }
    }
};

const Bullet = struct {
    pos_x: f32,
    pos_y: f32,
    width: f32,
    height: f32,
    speed: f32,
    direction: Vec2,
    velocity: Vec2,
    is_active: bool,
    game_state_p: *GameState,

    pub fn initStateless(bullet_config: Config.Bullet) @This() {
        return .{
            .pos_x = 0,
            .pos_y = 0,
            .width = bullet_config.width,
            .height = bullet_config.height,
            .speed = bullet_config.speed,
            .is_active = false,
            .game_state_p = undefined,
            .direction = undefined,
            .velocity = undefined,
        };
    }

    pub fn draw(self: @This()) void {
        if (self.is_active) {
            rl.drawRectangle(
                @intFromFloat(self.pos_x),
                @intFromFloat(self.pos_y),
                @intFromFloat(self.width),
                @intFromFloat(self.height),
                rl.Color.red,
            );
        }
    }

    pub fn update(self: *@This()) void {
        if (self.is_active) {
            self.*.pos_x += self.velocity.x;
            self.*.pos_y += self.velocity.y;
        }
        // TODO: Generalise check for out of bounds
        if (self.pos_y < 0) {
            self.is_active = false;
        }
    }

    pub fn fire(self: *@This(), emitter_x: f32, emitter_y: f32, direction: Vec2) void {
        // correct position based on bullet dimensions
        self.pos_x = emitter_x - (self.width / 2);
        self.pos_y = emitter_y + (self.height / 2);
        const unit_direction = direction.normalised();
        self.direction = unit_direction;
        self.velocity = unit_direction.scale(self.speed);
        self.is_active = true;
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
    }
};
const Shield = struct {
    pos_x: f32,
    pos_y: f32,
    width: f32,
    height: f32,
    health: u8,
    max_health: u8,
    game_state_p: *GameState,

    pub fn initStateless(shield_config: Config.Shield, x: f32, y: f32) @This() {
        return .{
            .pos_x = x,
            .pos_y = y,
            .width = shield_config.width,
            .height = shield_config.height,
            .health = 3, // default health
            .max_health = 3,
            .game_state_p = undefined,
        };
    }

    pub fn draw(self: @This()) void {
        if (self.health > 0) {
            rl.drawRectangle(
                @intFromFloat(self.pos_x),
                @intFromFloat(self.pos_y),
                @intFromFloat(self.width),
                @intFromFloat(self.height),
                rl.Color.green,
            );
        }
    }

    pub fn update(self: *@This()) void {
        // TODO: Handle collision with bullets
        if (self.*.health <= 0) {
            std.debug.print("dead", .{});
        }
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.*.game_state_p = game_state_p;
    }

    pub fn isHit(self: *@This(), bullet: *Bullet) bool {
        if (!bullet.is_active) return false;
        const rect = Rect{
            .x = self.pos_x,
            .y = self.pos_y,
            .width = self.width,
            .height = self.height,
        };
        const bulletRect = Rect{
            .x = bullet.pos_x,
            .y = bullet.pos_y,
            .width = bullet.width,
            .height = bullet.height,
        };
        if (rect.intersects(bulletRect)) {
            self.*.health -= 1;
            return true;
        }
        return false;
    }
};

const ShieldManager = struct {
    shields: [3]Shield,
    allocator: Allocator,
    game_state_p: *GameState,

    pub fn initStateless(allocator: Allocator, shield_config: Config.Shield) !@This() {
        const shields: [3]Shield = undefined;
        const screenWidthF: f32 = 1280.0; // assuming screen width
        const spacingX: f32 = shield_config.spacing * 2;
        const startX: f32 = (screenWidthF / 2.0) - (spacingX * 1.5);
        const startY: f32 = 400.0;

        for (shields, 0..) |*shield, i| {
            shield.* = Shield.initStateless(shield_config, startX + (@as(f32, @floatFromInt(i)) * spacingX), startY);
        }

        return .{
            .shields = shields,
            .allocator = allocator,
            .game_state_p = undefined,
        };
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        for (self.*.shields) |*shield| {
            shield.attachGameState(game_state_p);
        }
    }

    pub fn draw(self: @This()) void {
        for (self.shields) |*shield| {
            shield.draw();
        }
    }

    pub fn update() void {
        // TODO: Handle collisions with bullets
    }

    pub fn isHit(self: *@This(), bullet: *Bullet) bool {
        for (self.*.shields) |*shield| {
            if (shield.isHit(bullet)) return true;
        }
        return false;
    }
};

const GameState = struct {
    game_config: Config.Game,
    bullet_pool_p: *[]Bullet,
    // entities needing access to game_state
    player_p: *Player,
    // TODO:
    // shields
    // invaders

    pub fn init(game_config: Config.Game, player_p: *Player, bullet_pool_p: *[]Bullet) @This() {
        return .{
            .game_config = game_config,
            .player_p = player_p,
            .bullet_pool_p = bullet_pool_p,
        };
    }

    pub fn update(self: *@This()) void {
        self.player_p.update();
        BulletHandler.update(self.bullet_pool_p);
    }

    pub fn draw(self: @This()) void {
        self.player_p.draw();
        BulletHandler.draw(self.bullet_pool_p.*);
    }

    pub fn fire_bullet(self: *@This(), emitter_x: f32, emitter_y: f32, direction: Vec2) void {
        BulletHandler.fire_bullet(self.bullet_pool_p, emitter_x, emitter_y, direction);
    }
};

const ActiveScreen = union(enum) {
    start_menu: StartMenu,
    game_loop: GameState,

    pub fn draw(self: @This()) void {
        switch (self) {
            .start_menu => |menu| menu.draw(),
        }
    }
};

const StartMenu = struct {
    startTextRect: rl.Rectangle,

    startText: *const [5:0]u8,
    startTextFontSize: i32,
    startTextWidth: i32,
    startTextX: i32,
    startTextY: i32,

    titleText: *const [12:0]u8,
    titleFontSize: i32,
    titleTextWidth: i32,
    titleTextX: i32,
    titleTextY: i32,

    startPressed: bool,

    pub fn init(gameConfig: Config.Game) @This() {
        const titleText = "Zig Invaderz";
        const titleFontSize = @as(f32, @floatFromInt(gameConfig.screenHeight)) / 10.0;
        const titleTextWidth = (rl.measureText(titleText, @intFromFloat(titleFontSize)));

        const startText = "Start";
        const startFontSize = @as(f32, @floatFromInt(gameConfig.screenHeight)) / 14.0;
        const startTextWidth = rl.measureText(startText, @intFromFloat(startFontSize));
        const startRectWidth = @as(f32, @floatFromInt(startTextWidth)) * 1.2;
        const startRectHeight = startFontSize * 1.5;
        const startYPosition: f32 = 3.0 / 4.0;
        return .{
            .titleText = titleText,
            .titleFontSize = @intFromFloat(titleFontSize),
            .titleTextWidth = titleTextWidth,
            .titleTextX = @intFromFloat((@as(f32, @floatFromInt(gameConfig.screenWidth)) / 2.0) - @as(f32, @floatFromInt(titleTextWidth)) / 2.0),
            .titleTextY = @intFromFloat((@as(f32, @floatFromInt(gameConfig.screenHeight)) / 2.0) - (titleFontSize / 2.0)),

            .startText = startText,
            .startTextFontSize = @intFromFloat(startFontSize),
            .startTextWidth = startTextWidth,
            .startTextX = @intFromFloat(@as(f32, @floatFromInt(gameConfig.screenWidth)) / 2.0 - (@as(f32, @floatFromInt(startTextWidth)) / 2.0)),
            .startTextY = @intFromFloat(((@as(f32, @floatFromInt(gameConfig.screenHeight))) * startYPosition) - (startFontSize / 2.0)),
            .startTextRect = rl.Rectangle{
                .width = startRectWidth,
                .height = startRectHeight,
                .x = (@as(f32, @floatFromInt(gameConfig.screenWidth)) / 2.0) - (startRectWidth / 2.0),
                .y = (@as(f32, @floatFromInt(gameConfig.screenHeight)) * startYPosition) - (startRectHeight / 2.0),
            },

            .startPressed = false,
        };
    }

    pub fn draw(self: @This()) void {
        rl.drawText(self.titleText, self.titleTextX, self.titleTextY, self.titleFontSize, rl.Color.green);
        rl.drawRectangle(@intFromFloat(self.startTextRect.x), @intFromFloat(self.startTextRect.y), @intFromFloat(self.startTextRect.width), @intFromFloat(self.startTextRect.height), rl.Color.black);
        rl.drawText(self.startText, self.startTextX, self.startTextY, self.startTextFontSize, rl.Color.green);

        if (self.isMouseOnStartRect()) {
            rl.drawRectangleLines(@intFromFloat(self.startTextRect.x), @intFromFloat(self.startTextRect.y), @intFromFloat(self.startTextRect.width), @intFromFloat(self.startTextRect.height), rl.Color.green);
        } else {
            rl.drawRectangleLines(@intFromFloat(self.startTextRect.x), @intFromFloat(self.startTextRect.y), @intFromFloat(self.startTextRect.width), @intFromFloat(self.startTextRect.height), rl.Color.red);
        }
    }

    pub fn isMouseOnStartRect(self: @This()) bool {
        const mousePos = rl.getMousePosition();
        return rl.checkCollisionPointRec(mousePos, self.startTextRect);
    }

    pub fn update(self: *@This()) void {
        if (self.isMouseOnStartRect() and rl.isMouseButtonPressed(rl.MouseButton.left)) {
            std.debug.print("start pressed in update function\n", .{});
            self.startPressed = true;
        }
    }
};

pub fn main() !void {
    var dba = std.heap.DebugAllocator(.{}){};
    const allocator = dba.allocator();
    defer _ = dba.deinit();

    // init window
    const screenWidth = 1280;
    const screenHeight = 760;
    rl.initWindow(screenWidth, screenHeight, "Zig Invaderz");

    const game_config = Config.Game.fromScreenDims(screenWidth, screenHeight);
    const startMenu = StartMenu.init(game_config);

    // create bullet pool
    var player_bullet_pool = (try allocator.alloc(Bullet, game_config.playerBulletPoolConfig.max_bullets));
    defer allocator.free(player_bullet_pool);
    for (player_bullet_pool) |*bullet| {
        bullet.* = Bullet.initStateless(game_config.playerBulletPoolConfig.bullet_config);
    }
    // create player
    var player: Player = Player.initStateless(game_config.playerConfig);
    // create game state
    var game_state = GameState.init(game_config, &player, &player_bullet_pool);

    // attach game state to entities requiring it

    player.attachGameState(&game_state);

    var activeScreen = ActiveScreen{ .start_menu = startMenu };

    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // window loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        switch (activeScreen) {
            .start_menu => |*menu| {
                if (menu.startPressed) {
                    activeScreen = ActiveScreen{ .game_loop = game_state };
                } else {
                    menu.update();
                    menu.draw();
                }
            },
            .game_loop => |*gameState| {
                gameState.update();
                gameState.draw();
            },
        }
    }
}
