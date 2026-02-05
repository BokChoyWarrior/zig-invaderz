const std = @import("std");
const zig_invaders = @import("zig_invaders");
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
const Config = @import("./Config.zig"); // Import the config
const assert = std.debug.assert;

const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
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
    fire_delay: u16,
    fire_timer: u16 = 0,
    // parents
    game_state_p: ?*GameState,
    // children
    bullet_pool_p: ?*BulletPool,

    pub fn initStateless(playerConfig: Config.Player) @This() {
        return .{
            .width = playerConfig.width,
            .height = playerConfig.height,
            .pos_x = playerConfig.startX,
            .pos_y = playerConfig.startY,
            .speed = playerConfig.speed,
            .fire_delay = playerConfig.fireDelay,
            .game_state_p = null,
            .bullet_pool_p = null,
        };
    }

    pub fn validate(self: @This()) void {
        assert(self.bullet_pool_p != null);
        assert(self.game_state_p != null);
        self.bullet_pool_p.?.validate();
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        self.bullet_pool_p.?.attachGameState(game_state_p);
    }

    pub fn attach_bullet_pool(self: *@This(), bullet_pool_p: *BulletPool) void {
        self.bullet_pool_p = bullet_pool_p;
    }

    pub fn draw(self: @This()) void {
        self.rect().draw(rl.Color.blue);
        self.bullet_pool_p.?.draw();
    }

    pub fn rect(self: @This()) Rect {
        return Rect{
            .height = self.height,
            .width = self.width,
            .x = self.pos_x,
            .y = self.pos_y,
        };
    }

    fn update_player(self: *@This()) void {
        // movement
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            self.pos_x -= self.speed;
        }
        if (rl.isKeyDown(rl.KeyboardKey.right)) {
            self.pos_x += self.speed;
        }
        self.pos_x = std.math.clamp(self.pos_x, 0, @as(f32, @floatFromInt(self.game_state_p.?.*.game_config.screenWidth)) - self.width);

        // shooting
        // TODO: Check if minimum time has passed since last shot
        if ((rl.isKeyPressed(rl.KeyboardKey.space) or
            rl.isKeyDown(rl.KeyboardKey.space) or
            rl.isKeyPressedRepeat(rl.KeyboardKey.space)) and
            self.fire_timer >= self.fire_delay)
        {
            self.fire_timer = 0;
            // Let bullet pool know where to fire from
            const bullet_start_x = self.pos_x + (self.width / 2.0);
            const bullet_start_y = self.pos_y;
            const direction = Vec2.init(0.0, -1.0);
            self.bullet_pool_p.?.fire_bullet(bullet_start_x, bullet_start_y, direction);
        }
        self.fire_timer += 1;
    }

    pub fn update(self: *@This()) void {
        self.update_player();
        self.bullet_pool_p.?.update();
    }
};

const BulletPool = struct {
    allocator: Allocator,
    // parents
    game_state_p: ?*GameState,
    // children
    bullets: []Bullet,

    pub fn initStateless(allocator: Allocator, bullet_pool_config: Config.BulletPool) !@This() {
        const bullets = (try allocator.alloc(Bullet, bullet_pool_config.max_bullets));

        // cannot iterate over dynamically allocated array slike this:
        for (bullets) |*bullet| {
            bullet.* = Bullet.initStateless(bullet_pool_config.bullet_config);
        }

        // instead we can use a loop to initialize each bullet
        // for (0..bullets.len) |i| {
        //     bullets[i].* = Bullet.initStateless(bullet_pool_config.bullet_config);
        // }

        return .{
            .bullets = bullets,
            .allocator = allocator,
            .game_state_p = null,
        };
    }

    pub fn validate(self: @This()) void {
        assert(self.game_state_p != null);
        for (self.bullets) |*bullet| {
            bullet.validate();
        }
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        for (self.bullets) |*bullet| {
            bullet.attachGameState(game_state_p);
        }
    }

    pub fn draw(self: @This()) void {
        for (self.bullets) |bullet| {
            bullet.draw();
        }
    }

    pub fn update(self: *@This()) void {
        for (self.bullets) |*bullet| {
            bullet.update();
        }
    }

    pub fn fire_bullet(self: *@This(), emitter_x: f32, emitter_y: f32, direction: Vec2) void {
        for (self.bullets) |*bullet| {
            if (!bullet.is_active) {
                bullet.fire(emitter_x, emitter_y, direction);
                break;
            }
        }
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.bullets);
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
    collides_with: Config.CollidesWith,
    // parents
    game_state_p: ?*GameState,

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
            .collides_with = bullet_config.collides_with,
        };
    }

    pub fn validate(self: @This()) void {
        assert(self.game_state_p != null);
    }

    pub fn draw(self: @This()) void {
        if (self.is_active) {
            rl.drawRectangle(
                @intFromFloat(self.pos_x),
                @intFromFloat(self.pos_y),
                @intFromFloat(self.width),
                @intFromFloat(self.height),
                rl.Color.yellow,
            );
        }
    }

    pub fn update(self: *@This()) void {
        if (self.is_active) {
            self.*.pos_x += self.velocity.x;
            self.*.pos_y += self.velocity.y;

            // TODO: Generalise check for out of bounds
            const screenWidthF = @as(f32, @floatFromInt(rl.getScreenWidth()));
            const screenHeightF = @as(f32, @floatFromInt(rl.getScreenHeight()));
            if ((self.pos_y < 0) or self.pos_x < 0 or self.pos_x > (screenWidthF - self.width) or self.pos_y > screenHeightF - self.height) {
                self.is_active = false;
            }

            if (self.collides_with.shield) {
                const intersectingShield = self.game_state_p.?.shield_manager_p.?.findIntersectingShieldForBullet(self.rect());
                if (intersectingShield != null) {
                    intersectingShield.?.takeDamage();
                    self.is_active = false;
                }
            }

            if (self.collides_with.invaders) {
                const intersectingInvader = self.game_state_p.?.invader_manager_p.?.findIntersectingInvaderForBullet(self.rect());
                if (intersectingInvader != null) {
                    intersectingInvader.?.*.kill();
                    self.is_active = false;
                }
            }

            if (self.collides_with.player) {
                // TODO
            }
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

    pub fn rect(self: @This()) Rect {
        return .{
            .x = self.pos_x,
            .y = self.pos_y,
            .width = self.width,
            .height = self.height,
        };
    }
};
const Shield = struct {
    pos_x: f32,
    pos_y: f32,
    width: f32,
    height: f32,
    health: u8,
    max_health: u8,
    colour: rl.Color,
    game_state_p: ?*GameState,

    pub fn initStateless(config: Config.Shield, x: f32, y: f32) @This() {
        return .{
            .pos_x = x,
            .pos_y = y,
            .width = config.width,
            .height = config.height,
            .health = config.max_health,
            .max_health = config.max_health,
            .colour = config.colour,
            .game_state_p = null,
        };
    }

    pub fn validate(self: @This()) void {
        assert(self.game_state_p != null);
    }

    pub fn rect(self: @This()) Rect {
        return Rect{
            .height = self.height,
            .width = self.width,
            .x = self.pos_x,
            .y = self.pos_y,
        };
    }

    pub fn draw(self: @This()) void {
        // just to avoid drawing if unnnecessary
        if (self.isAlive()) {
            rl.drawRectangle(
                @intFromFloat(self.pos_x),
                @intFromFloat(self.pos_y),
                @intFromFloat(self.width),
                @intFromFloat(self.height),
                self.colour,
            );
        }
    }

    fn updateColourAlpha(self: *@This()) void {
        const alphaUnit = @as(f32, @floatFromInt(self.health)) / @as(f32, @floatFromInt(self.max_health));
        self.colour = self.colour.alpha(alphaUnit);
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
    }

    pub fn takeDamage(self: *@This()) void {
        self.health -= 1;
        self.updateColourAlpha();
    }

    pub fn isAlive(self: @This()) bool {
        return self.health > 0;
    }
};

const NUM_SHIELDS = 5;

const ShieldManager = struct {
    shields: [NUM_SHIELDS]Shield,
    group_width: f32,
    group_height: f32,
    group_x: f32,
    group_y: f32,
    game_state_p: ?*GameState,

    pub fn initStateless(config: Config.Shield) @This() {
        const group_width = (config.width * NUM_SHIELDS) + ((config.width * config.spacing_factor) * (NUM_SHIELDS - 1));
        const group_height = config.height;

        const group_x = (@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0) - (group_width / 2.0);
        std.debug.print("shields start x: {}\ngroup_width: {}\n", .{ group_x, group_width });
        const group_y = (@as(f32, @floatFromInt(rl.getScreenHeight()))) - 100.0;

        var shields: [NUM_SHIELDS]Shield = undefined;

        for (&shields, 0..NUM_SHIELDS) |*shield, i| {
            shield.* = Shield.initStateless(
                config,
                group_x + (@as(f32, @floatFromInt(i)) * ((config.spacing_factor + 1) * config.width)),
                group_y - (config.height / 2.0),
            );
        }

        return .{
            .shields = shields,
            .group_y = group_y,
            .group_x = group_x,
            .group_width = group_width,
            .group_height = group_height,
            .game_state_p = null,
        };
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        for (&self.shields) |*shield| {
            shield.attachGameState(game_state_p);
        }
    }

    pub fn validate(self: @This()) void {
        assert(self.game_state_p != null);
        for (self.shields) |shield| {
            shield.validate();
        }
    }

    pub fn draw(self: @This()) void {
        for (self.shields) |shield| {
            shield.draw();
        }
    }

    // pub fn update(self: *@This()) void {
    //     for (&self.shields) |*shield| {
    //         shield.update();
    //     }
    // }

    // generic rect, maybe we want to add bombs or other projectiles later
    // returns shield pointer to callee so they can do something with it (damage, etc)
    pub fn findIntersectingShieldForBullet(self: *@This(), other_rect: Rect) ?*Shield {
        for (&self.shields) |*shield| {
            if (shield.isAlive() and shield.rect().intersects(other_rect)) return shield;
            // shouldn't hit two at once!
        }
        return null;
    }
};

const Invader = struct {
    config: Config.Invader,
    pos_x: f32,
    pos_y: f32,
    width: f32,
    height: f32,
    colour: rl.Color,
    is_alive: bool,

    game_state_p: ?*GameState,

    pub fn initStateless(config: Config.Invader, x: f32, y: f32) @This() {
        return .{
            .pos_x = x,
            .pos_y = y,
            .width = config.width,
            .height = config.height,
            .colour = config.colour,
            .is_alive = true,
            .config = config,
            .game_state_p = null,
        };
    }

    pub fn validate(self: @This()) void {
        assert(self.game_state_p != null);
    }

    pub fn rect(self: @This()) Rect {
        return Rect{
            .height = self.height,
            .width = self.width,
            .x = self.pos_x,
            .y = self.pos_y,
        };
    }

    pub fn draw(self: @This()) void {
        if (self.is_alive) {
            rl.drawRectangle(
                @intFromFloat(self.pos_x),
                @intFromFloat(self.pos_y),
                @intFromFloat(self.width),
                @intFromFloat(self.height),
                self.colour,
            );
        }
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
    }

    pub fn kill(self: *@This()) void {
        self.is_alive = false;
    }
};

const INVADERS_COLS = 10;
const INVADERS_ROWS = 5;

const InvaderManager = struct {
    config: Config.Invader,
    group_width: f32,
    group_height: f32,
    group_x: f32,
    group_y: f32,
    direction_x: enum(i2) { left = -1, right = 1 },
    speed: f32,
    rand: std.Random,
    move_delay: u16,
    move_timer: u16 = 0,

    // parent
    game_state_p: ?*GameState = null,
    // children
    invaders: [INVADERS_ROWS][INVADERS_COLS]Invader,
    bullet_pool_p: ?*BulletPool = null,
    // invaders_flat: [NUM_INVADERS_X * NUM_INVADERS_Y]*Invader,

    pub fn initStateless(invader_config: Config.Invader, rand: std.Random) @This() {
        // num invaders heights (width*n) + inbetween spaces heights (width*(n-1))
        const group_width = invader_config.width * ((2 * INVADERS_COLS) - 1);
        const group_height = invader_config.height * 2 * (INVADERS_ROWS - 1);

        const group_x = (@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0) - (group_width / 2.0);
        const group_y = 50.0;

        var invaders: [INVADERS_ROWS][INVADERS_COLS]Invader = undefined;
        // var flatInvaders: [NUM_INVADERS_X * NUM_INVADERS_Y]*Invader = undefined;

        for (&invaders, 0..INVADERS_ROWS) |*row, y| {
            for (row, 0..INVADERS_COLS) |*invader, x| {
                const pos_x = (@as(f32, @floatFromInt(x)) * (invader_config.width * 2)) + group_x;
                const pos_y = (@as(f32, @floatFromInt(y)) * (invader_config.height * 2)) + group_y;
                const thisInvader = Invader.initStateless(invader_config, pos_x, pos_y);
                invader.* = thisInvader;

                // const flatArrayIndex = (y * NUM_INVADERS_Y) + x;
                // flatInvaders[flatArrayIndex] = invader;

                // const flat0 = flatInvaders[0];
                // const mdim0 = invaders[0][0];
                // assert(std.meta.eql(flat0, &mdim0));
            }
        }

        return .{
            .config = invader_config,
            .invaders = invaders,
            .direction_x = .right,
            .speed = invader_config.speed,
            .group_width = group_width,
            .group_height = group_height,
            .group_x = group_x,
            .group_y = group_y,
            .rand = rand,
            .move_delay = invader_config.move_delay,
        };
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        for (&self.invaders) |*row| {
            for (row) |*invader| {
                invader.attachGameState(game_state_p);
            }
        }
        self.bullet_pool_p.?.attachGameState(game_state_p);
    }

    pub fn validate(self: *@This()) void {
        assert(self.game_state_p != null);
        assert(self.bullet_pool_p != null);
        for (&self.invaders) |*row| {
            for (row) |*invader| {
                invader.validate();
            }
        }
        self.bullet_pool_p.?.validate();

        // for (&self.invaders_flat) |invader_p| {
        //     invader_p.*.validate();
        // }
    }

    pub fn draw(self: @This()) void {
        for (self.invaders) |row| {
            for (row) |invader| {
                invader.draw();
            }
        }
        self.bullet_pool_p.?.draw();
    }

    fn move(self: *@This()) void {
        var x_change: f32 = 0.0;
        var y_change: f32 = 0.0;

        // check if group is touching screen edges, and if so, reverse direction and move down
        if (self.group_x <= 0 or self.group_x >= @as(f32, @floatFromInt(rl.getScreenWidth())) - self.group_width) {
            (self.direction_x) = @enumFromInt(@intFromEnum(self.direction_x) * -1);

            y_change = self.speed * @as(f32, @floatFromInt(self.move_delay));
        }

        self.group_y += y_change;

        x_change = (self.speed * @as(f32, @floatFromInt(@intFromEnum(self.direction_x))) * @as(f32, @floatFromInt(self.move_delay)));

        // we must modify the x value before testing for screen edges, otherwise
        self.group_x += x_change;

        var i: u8 = 0;
        while (self.getInvader(i)) |invader| : (i += 1) {
            invader.*.pos_x += x_change;
            invader.*.pos_y += y_change;
        }
    }

    fn randomly_fire(self: *@This()) void {
        var i: u8 = 0;
        while (self.getInvader(i)) |invader| : (i += 1) {
            if (invader.is_alive and self.rand.intRangeAtMost(u16, 0, 10000) < 5) {
                self.bullet_pool_p.?.fire_bullet(invader.*.pos_x, invader.*.pos_y, Vec2.init(0.0, 1.0));
            }
        }
    }
    pub fn update(self: *@This()) void {
        if (self.move_timer >= self.move_delay) {
            self.move();
            self.move_timer = 0;
        }
        self.move_timer += 1;
        self.randomly_fire();
        self.bullet_pool_p.?.update();
    }

    // generic rect, maybe we want to add bombs or other projectiles later
    // returns shield pointer to callee so they can do something with it (damage, etc)
    pub fn findIntersectingInvaderForBullet(self: *@This(), other_rect: Rect) ?*Invader {
        for (&self.invaders) |*row| {
            for (row) |*invader| {
                if (invader.is_alive and invader.rect().intersects(other_rect)) return invader;
            }
        }
        return null;
    }

    pub fn getInvader(self: *@This(), index: u8) ?*Invader {
        const row = index / INVADERS_COLS;
        const col = index % INVADERS_COLS;
        if (row >= INVADERS_ROWS) return null;
        return &self.invaders[row][col];
    }

    pub fn attach_bullet_pool(self: *@This(), bullet_pool_p: *BulletPool) void {
        self.bullet_pool_p = bullet_pool_p;
    }
};

const GameState = struct {
    game_config: Config.Game,
    // entities needing access to game_state should also be added to the validate function (and if necessary implement a similar function of their own)
    player_p: ?*Player,
    shield_manager_p: ?*ShieldManager,
    invader_manager_p: ?*InvaderManager,

    pub fn init(
        game_config: Config.Game,
        player_p: *Player,
        shield_manager_p: *ShieldManager,
        invader_manager_p: *InvaderManager,
    ) @This() {
        return .{
            .game_config = game_config,
            .player_p = player_p,
            .shield_manager_p = shield_manager_p,
            .invader_manager_p = invader_manager_p,
        };
    }

    pub fn update(self: *@This()) void {
        self.player_p.?.update();
        self.invader_manager_p.?.update();
        // self.shield_manager_p.?.update();
    }

    pub fn draw(self: @This()) void {
        self.player_p.?.draw();
        self.shield_manager_p.?.draw();
        self.invader_manager_p.?.draw();
    }

    pub fn validate(self: @This()) void {
        assert(self.player_p != null);
        assert(self.shield_manager_p != null);
        assert(self.invader_manager_p != null);
        self.player_p.?.validate();
        self.shield_manager_p.?.validate();
        self.invader_manager_p.?.validate();
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
            self.startPressed = true;
        }
    }
};

pub fn main() !void {
    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var dba = std.heap.DebugAllocator(.{}){};
    const allocator = dba.allocator();
    defer _ = dba.deinit();

    // init window
    const screenWidth = 1280;
    const screenHeight = 760;
    rl.initWindow(screenWidth, screenHeight, "Zig Invaderz");

    const game_config = Config.Game.fromScreenDims(screenWidth, screenHeight);
    const startMenu = StartMenu.init(game_config);

    var player_bullet_pool = try BulletPool.initStateless(allocator, game_config.playerBulletPoolConfig);
    defer player_bullet_pool.deinit();
    var player: Player = Player.initStateless(game_config.playerConfig);

    var shield_mgr = ShieldManager.initStateless(game_config.shieldConfig);

    const invader_bullet_pool_config = Config.BulletPool.init(5, Config.Bullet.init(5, 5, 10, .{ .player = true, .shield = true }));
    var invader_bullet_pool = try BulletPool.initStateless(allocator, invader_bullet_pool_config);
    defer invader_bullet_pool.deinit();
    var invader_mgr = InvaderManager.initStateless(game_config.invaderConfig, rand);
    // create game state
    // maybe we should also return the `validate` function here, to help remind the idiot behind the keyboard to actually invoke this function at some point
    var game_state = GameState.init(game_config, &player, &shield_mgr, &invader_mgr);

    // attach game state to entities requiring it

    // TODO: Why not just create player with the bullet pool attached? (And invader manager ofc)
    player.attach_bullet_pool(&player_bullet_pool);
    player.attachGameState(&game_state);

    shield_mgr.attachGameState(&game_state);

    invader_mgr.attach_bullet_pool(&invader_bullet_pool);
    invader_mgr.attachGameState(&game_state);

    game_state.validate();

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
