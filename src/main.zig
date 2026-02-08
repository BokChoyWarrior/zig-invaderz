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
    speed: f32,
    fire_delay: u16,
    texture: rl.Texture2D,

    pos_x: f32,
    pos_y: f32,
    fire_timer: u16 = 0,
    // parents
    game_state_p: ?*GameState,
    // children
    bullet_pool_p: BulletPool,

    pub const Options = struct {
        width: f32 = 50,
        height: f32 = 60,
        speed: f32 = 5,
        fire_delay: u16 = 20,
    };

    pub fn initStateless(allocator: Allocator, options: Options) !@This() {
        const player_bullet_pool = try BulletPool.initStateless(allocator, .{
            .bullet_options = .{
                .collides_with = .{ .shield = true, .invaders = true },
            },
        });

        const texture = try rl.Texture2D.init("/home/harv/dev/zig/zig-invaders/src/images/cat-girl.png");

        return .{
            .width = options.width,
            .height = options.height,
            .speed = options.speed,
            .fire_delay = options.fire_delay,
            .texture = texture,
            .pos_x = @as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0,
            .pos_y = @as(f32, @floatFromInt(rl.getScreenHeight())) - options.height,
            .bullet_pool_p = player_bullet_pool,
            .game_state_p = null,
        };
    }

    pub fn reset(self: *@This()) void {
        self.fire_timer = 0;
        self.pos_x = @as(f32, @floatFromInt(@divFloor(rl.getScreenWidth(), 2)));
        self.bullet_pool_p.reset();
    }

    pub fn deinit(self: *@This()) void {
        self.bullet_pool_p.deinit();
    }

    pub fn validate(self: @This()) void {
        assert(self.game_state_p != null);
        self.bullet_pool_p.validate();
    }

    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        self.bullet_pool_p.attachGameState(game_state_p);
    }

    pub fn draw(self: @This()) void {
        const sourceRect = rl.Rectangle.init(0.0, 0.0, @as(f32, @floatFromInt(self.texture.width)), @as(f32, @floatFromInt(self.texture.height)));
        const destRect = rl.Rectangle.init(self.pos_x, self.pos_y, self.width, self.height);
        const origin = rl.Vector2.init(0.0, 0.0);
        const rotation = 0.0;
        rl.drawTexturePro(self.texture, sourceRect, destRect, origin, rotation, rl.Color.white);

        self.bullet_pool_p.draw();
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
        self.pos_x = std.math.clamp(self.pos_x, 0, @as(f32, @floatFromInt(self.game_state_p.?.*.options.screenWidth)) - self.width);

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
            self.bullet_pool_p.fire_bullet(bullet_start_x, bullet_start_y, direction);
        }
        self.fire_timer += 1;
    }

    pub fn update(self: *@This()) void {
        self.update_player();
        self.bullet_pool_p.update();
    }
};

const BulletPool = struct {
    allocator: Allocator,
    // parents
    game_state_p: ?*GameState,
    // children
    bullets: []Bullet,

    pub const Options = struct {
        bullet_count: u8 = 10,
        bullet_options: Bullet.Options = .{},
    };

    pub fn initStateless(allocator: Allocator, options: Options) !@This() {
        const bullets = (try allocator.alloc(Bullet, options.bullet_count));
        for (bullets) |*bullet| {
            bullet.* = Bullet.initStateless(options.bullet_options);
        }

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

    pub fn reset(self: *@This()) void {
        for (self.bullets) |*bullet| {
            bullet.is_active = false;
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
    width: f32,
    height: f32,
    speed: f32,
    direction: Vec2,
    collides_with: Config.CollidesWith,

    velocity: Vec2,
    pos_x: f32,
    pos_y: f32,
    is_active: bool,
    // parents
    game_state_p: ?*GameState = null,

    pub const Options = struct {
        width: f32 = 5.0,
        height: f32 = 5.0,
        speed: f32 = 10.0,
        collides_with: Config.CollidesWith = .{},
    };

    pub fn initStateless(options: Options) @This() {
        return .{
            .width = options.width,
            .height = options.height,
            .speed = options.speed,
            .collides_with = options.collides_with,
            .pos_x = 0,
            .pos_y = 0,
            .is_active = false,
            .direction = undefined,
            .velocity = undefined,
            .game_state_p = null,
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
                const intersectingShield = self.game_state_p.?.shield_manager_p.findIntersectingShieldForBullet(self.rect());
                if (intersectingShield != null) {
                    intersectingShield.?.takeDamage();
                    self.is_active = false;
                }
            }

            if (self.collides_with.invaders) {
                const intersectingInvader = self.game_state_p.?.invader_manager_p.findIntersectingInvaderForBullet(self.rect());
                if (intersectingInvader != null) {
                    intersectingInvader.?.*.kill();
                    self.game_state_p.?.increase_score();
                    self.is_active = false;
                }
            }

            if (self.collides_with.player) {
                // TODO
                if (self.rect().intersects(self.game_state_p.?.player_p.rect())) {
                    self.game_state_p.?.kill_player();
                }
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
    texture: rl.Texture2D,
    game_state_p: ?*GameState,

    pub fn initStateless(options: ShieldManager.Options, x: f32, y: f32, texture: rl.Texture2D) @This() {
        return .{
            .pos_x = x,
            .pos_y = y,
            .width = options.width,
            .height = options.height,
            .health = options.max_health,
            .max_health = options.max_health,
            .colour = options.colour,
            .texture = texture,
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
            const sourceRect = rl.Rectangle.init(0.0, 0.0, @as(f32, @floatFromInt(self.texture.width)), @as(f32, @floatFromInt(self.texture.height)));
            const destRect = rl.Rectangle.init(self.pos_x, self.pos_y, self.width, self.height);
            const origin = rl.Vector2.init(0.0, 0.0);
            const rotation = 0.0;
            rl.drawTexturePro(self.texture, sourceRect, destRect, origin, rotation, self.colour);
            // rl.drawRectangle(
            //     @intFromFloat(self.pos_x),
            //     @intFromFloat(self.pos_y),
            //     @intFromFloat(self.width),
            //     @intFromFloat(self.height),
            //     self.colour,
            // );
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
    texture: rl.Texture2D,
    options: Options,
    game_state_p: ?*GameState,

    pub const Options = struct {
        width: f32 = 100,
        height: f32 = 60,
        max_health: u8 = 10,
        spacing_factor: f32 = 2.0,
        colour: rl.Color = rl.Color.white,
    };

    pub fn initStateless(options: Options) !@This() {
        const texture = try rl.Texture2D.init("/home/harv/dev/zig/zig-invaders/src/images/shield_girl.png");

        const group_width = (options.width * NUM_SHIELDS) + ((options.width * options.spacing_factor) * (NUM_SHIELDS - 1));
        const group_height = options.height;

        const group_x = (@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0) - (group_width / 2.0);
        std.debug.print("shields start x: {}\ngroup_width: {}\n", .{ group_x, group_width });
        const group_y = (@as(f32, @floatFromInt(rl.getScreenHeight()))) - 150.0;

        var shields: [NUM_SHIELDS]Shield = undefined;

        for (&shields, 0..NUM_SHIELDS) |*shield, i| {
            shield.* = Shield.initStateless(
                options,
                group_x + (@as(f32, @floatFromInt(i)) * ((options.spacing_factor + 1) * options.width)),
                group_y - (options.height / 2.0),
                texture,
            );
        }

        return .{
            .shields = shields,
            .group_y = group_y,
            .group_x = group_x,
            .group_width = group_width,
            .group_height = group_height,
            .texture = texture,
            .options = options,
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

    pub fn reset(self: *@This()) void {
        for (&self.shields) |*shield| {
            shield.health = shield.max_health;
            shield.colour = self.options.colour;
        }
    }

    pub fn draw(self: @This()) void {
        for (self.shields) |shield| {
            shield.draw();
        }
    }

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
    width: f32,
    height: f32,
    colour: rl.Color,
    options: Options,
    pos_x: f32,
    pos_y: f32,
    initial_x: f32,
    initial_y: f32,
    is_alive: bool,

    game_state_p: ?*GameState,

    pub const Options = struct {
        width: f32 = 40,
        height: f32 = 20,
        colour: rl.Color = rl.Color.green,
        speed: f32 = 10,
    };

    pub fn initStateless(options: Options, x: f32, y: f32) @This() {
        return .{
            .pos_x = x,
            .pos_y = y,
            .initial_x = x,
            .initial_y = y,
            .width = options.width,
            .height = options.height,
            .colour = options.colour,
            .options = options,
            .is_alive = true,
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

    pub fn reset(self: *@This()) void {
        self.is_alive = true;
        self.pos_x = self.initial_x;
        self.pos_y = self.initial_y;
    }
};

const INVADERS_COLS = 10;
const INVADERS_ROWS = 5;

const InvaderManager = struct {
    options: Options,
    group_width: f32,
    group_height: f32,
    group_x: f32,
    group_y: f32,
    spacing: f32,
    direction_x: enum(i2) { left = -1, right = 1 },
    speed: f32,
    rand: std.Random,
    move_delay: u16,
    move_timer: u16 = 0,
    has_recently_descended: bool = false,

    // parent
    game_state_p: ?*GameState = null,
    // children
    invaders: [INVADERS_ROWS][INVADERS_COLS]Invader,
    bullet_pool_p: BulletPool,
    // invaders_flat: [NUM_INVADERS_X * NUM_INVADERS_Y]*Invader,

    pub const Options = struct {
        move_delay: u16 = 30,
        speed: f32 = 1.0,
        spacing: f32 = 2.5,
        bullet_pool: BulletPool.Options = .{},
        invader: Invader.Options = .{},
    };

    pub fn initStateless(allocator: Allocator, rand: std.Random, options: Options) !@This() {
        // num invaders heights (width*n) + inbetween spaces heights (width*(n-1))
        const group_width = options.invader.width * ((options.spacing * INVADERS_COLS) - 1);
        const group_height = options.invader.height * options.spacing * (INVADERS_ROWS - 1);

        const group_x = (@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0) - (group_width / 2.0);
        const group_y = 50.0;

        var invaders: [INVADERS_ROWS][INVADERS_COLS]Invader = undefined;
        // var flatInvaders: [NUM_INVADERS_X * NUM_INVADERS_Y]*Invader = undefined;

        for (&invaders, 0..INVADERS_ROWS) |*row, y| {
            for (row, 0..INVADERS_COLS) |*invader, x| {
                const pos_x = (@as(f32, @floatFromInt(x)) * (options.invader.width * options.spacing)) + group_x;
                const pos_y = (@as(f32, @floatFromInt(y)) * (options.invader.height * options.spacing)) + group_y;
                const thisInvader = Invader.initStateless(options.invader, pos_x, pos_y);
                invader.* = thisInvader;

                // const flatArrayIndex = (y * NUM_INVADERS_Y) + x;
                // flatInvaders[flatArrayIndex] = invader;

                // const flat0 = flatInvaders[0];
                // const mdim0 = invaders[0][0];
                // assert(std.meta.eql(flat0, &mdim0));
            }
        }

        const invader_bullet_pool = try BulletPool.initStateless(
            allocator,
            .{
                .bullet_options = .{
                    .collides_with = .{ .shield = true, .player = true },
                },
            },
        );

        return .{
            .options = options,
            .spacing = options.spacing,
            .invaders = invaders,
            .direction_x = .right,
            .speed = options.speed,
            .group_width = group_width,
            .group_height = group_height,
            .group_x = group_x,
            .group_y = group_y,
            .rand = rand,
            .move_delay = options.move_delay,
            .bullet_pool_p = invader_bullet_pool,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.bullet_pool_p.deinit();
    }

    pub fn reset(self: *@This()) void {
        self.group_x = (@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0) - (self.group_width / 2.0);
        self.group_y = 50.0;
        self.direction_x = .right;
        self.move_timer = 0;
        self.bullet_pool_p.reset();
        for (&self.invaders) |*row| {
            for (row) |*invader| {
                invader.reset();
            }
        }
    }
    pub fn attachGameState(self: *@This(), game_state_p: *GameState) void {
        self.game_state_p = game_state_p;
        for (&self.invaders) |*row| {
            for (row) |*invader| {
                invader.attachGameState(game_state_p);
            }
        }
        self.bullet_pool_p.attachGameState(game_state_p);
    }

    pub fn validate(self: *@This()) void {
        assert(self.game_state_p != null);
        for (&self.invaders) |*row| {
            for (row) |*invader| {
                invader.validate();
            }
        }
        self.bullet_pool_p.validate();
    }

    pub fn draw(self: @This()) void {
        for (self.invaders) |row| {
            for (row) |invader| {
                invader.draw();
            }
        }
        self.bullet_pool_p.draw();
    }

    fn is_touching_edges(self: @This()) bool {
        return self.group_x <= 0 or self.group_x >= @as(f32, @floatFromInt(rl.getScreenWidth())) - self.group_width;
    }

    fn move(self: *@This()) void {
        var x_change: f32 = 0.0;
        var y_change: f32 = 0.0;

        if (!self.is_touching_edges() or self.has_recently_descended) {
            self.has_recently_descended = false;
            x_change = (self.speed * @as(f32, @floatFromInt(@intFromEnum(self.direction_x))) * @as(f32, @floatFromInt(self.move_delay)));
            // we must modify the x value before testing for screen edges, otherwise
            self.group_x += x_change;
        } else if (self.is_touching_edges()) {
            (self.direction_x) = @enumFromInt(@intFromEnum(self.direction_x) * -1);
            y_change = self.speed * @as(f32, @floatFromInt(self.move_delay));
            self.group_y += y_change;
            self.has_recently_descended = true;
        }

        var i: u8 = 0;
        while (self.getInvader(i)) |invader| : (i += 1) {
            invader.*.pos_x += x_change;
            invader.*.pos_y += y_change;
        }
    }

    fn randomly_fire(self: *@This()) void {
        var i: u8 = 0;
        while (self.getInvader(i)) |invader| : (i += 1) {
            if (invader.is_alive and self.rand.intRangeAtMost(u16, 0, 5000) < 5) {
                const x = invader.pos_x + (invader.width / 2.0);
                const y = invader.pos_y + invader.height;
                self.bullet_pool_p.fire_bullet(x, y, Vec2.init(0.0, 1.0));
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
        self.bullet_pool_p.update();
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
};

const GameState = struct {
    options: Options,
    score: u32 = 0,
    game_over: bool = false, // could make this an enum later: playing, dead, survived etc?
    // entities needing access to game_state should also be added to the validate function (and if necessary implement a similar function of their own)
    player_p: Player,
    shield_manager_p: ShieldManager,
    invader_manager_p: InvaderManager,

    pub const Options = struct {
        screenWidth: i32 = 1280,
        screenHeight: i32 = 720,
        shields_opt: ShieldManager.Options = .{},
        invader_opt: InvaderManager.Options = .{},
        player_opt: Player.Options = .{},
    };

    pub fn init(allocator: Allocator, rand: std.Random, options: Options) !@This() {
        const shield_mgr = try ShieldManager.initStateless(options.shields_opt);

        const invader_mgr = try InvaderManager.initStateless(allocator, rand, options.invader_opt);

        const player: Player = try Player.initStateless(allocator, options.player_opt);

        return .{
            .options = options,
            .shield_manager_p = shield_mgr,
            .player_p = player,
            .invader_manager_p = invader_mgr,
        };
    }

    pub fn attachSelfToEntities(self: *GameState) void {
        self.shield_manager_p.attachGameState(self);
        self.invader_manager_p.attachGameState(self);
        self.player_p.attachGameState(self);
    }

    pub fn deinit(self: *@This()) void {
        self.invader_manager_p.deinit();
        self.player_p.deinit();
    }

    pub fn update(self: *@This()) void {
        self.invader_manager_p.update();
        self.player_p.update();
    }

    pub fn draw(self: *@This()) void {
        self.player_p.draw();
        self.drawScore();
        self.shield_manager_p.draw();
        self.invader_manager_p.draw();
    }

    pub fn validate(self: *@This()) void {
        self.invader_manager_p.validate();
        self.shield_manager_p.validate();
        self.player_p.validate();
    }

    pub fn reset(self: *@This()) void {
        self.score = 0;
        self.game_over = false;
        self.invader_manager_p.reset();
        self.player_p.reset();
        self.shield_manager_p.reset();
    }

    pub fn drawScore(self: @This()) void {
        // std.debug.print("score: {}\n", .{self.score});
        rl.drawText(rl.textFormat("Score: %d", .{self.score}), 50, rl.getScreenHeight() - 80, 40, rl.Color.white);
    }

    pub fn increase_score(self: *@This()) void {
        self.score += 100;
    }

    pub fn kill_player(self: *@This()) void {
        self.game_over = true;
    }
};

const ActiveScreen = union(enum) {
    start_menu: *StartMenu,
    game_loop: *GameState,
    game_over: *GameOver,

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

    pub fn init() @This() {
        const screenHeight = 720;
        const screenWidth = 1280;
        const titleText = "Zig Invaderz";
        const titleFontSize = @as(f32, @floatFromInt(screenHeight)) / 10.0;
        const titleTextWidth = (rl.measureText(titleText, @intFromFloat(titleFontSize)));

        const startText = "Start";
        const startFontSize = @as(f32, @floatFromInt(screenHeight)) / 14.0;
        const startTextWidth = rl.measureText(startText, @intFromFloat(startFontSize));
        const startRectWidth = @as(f32, @floatFromInt(startTextWidth)) * 1.2;
        const startRectHeight = startFontSize * 1.5;
        const startYPosition: f32 = 3.0 / 4.0;
        return .{
            .titleText = titleText,
            .titleFontSize = @intFromFloat(titleFontSize),
            .titleTextWidth = titleTextWidth,
            .titleTextX = @intFromFloat((@as(f32, @floatFromInt(screenWidth)) / 2.0) - @as(f32, @floatFromInt(titleTextWidth)) / 2.0),
            .titleTextY = @intFromFloat((@as(f32, @floatFromInt(screenHeight)) / 2.0) - (titleFontSize / 2.0)),

            .startText = startText,
            .startTextFontSize = @intFromFloat(startFontSize),
            .startTextWidth = startTextWidth,
            .startTextX = @intFromFloat(@as(f32, @floatFromInt(screenWidth)) / 2.0 - (@as(f32, @floatFromInt(startTextWidth)) / 2.0)),
            .startTextY = @intFromFloat(((@as(f32, @floatFromInt(screenHeight))) * startYPosition) - (startFontSize / 2.0)),
            .startTextRect = rl.Rectangle{
                .width = startRectWidth,
                .height = startRectHeight,
                .x = (@as(f32, @floatFromInt(screenWidth)) / 2.0) - (startRectWidth / 2.0),
                .y = (@as(f32, @floatFromInt(screenHeight)) * startYPosition) - (startRectHeight / 2.0),
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

const GameOver = struct {
    score: u32,
    playAgain: bool = false,

    pub fn init(score: u32) @This() {
        return .{
            .score = score,
        };
    }

    pub fn draw(self: @This()) void {
        // Draw score
        const game_over_text = rl.textFormat("GAME OVER!", .{self.score});
        const game_over_width = rl.measureText(game_over_text, Config.LARGE_FONT_SIZE);

        rl.drawText(
            game_over_text,
            @intFromFloat(@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0 - @as(f32, @floatFromInt(game_over_width)) / 2.0),
            @intFromFloat(@as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0 - 120.0),
            Config.LARGE_FONT_SIZE,
            rl.Color.red,
        );

        const score_text = rl.textFormat("Score: %d", .{self.score});
        const score_width = rl.measureText(score_text, Config.FONT_SIZE);

        rl.drawText(
            score_text,
            @intFromFloat(@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0 - @as(f32, @floatFromInt(score_width)) / 2.0),
            @intFromFloat(@as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0 - 50.0),
            Config.FONT_SIZE,
            rl.Color.white,
        );

        // Draw play again button
        const playAgainText = "Play Again";
        const playAgainTextWidth = rl.measureText(playAgainText, Config.FONT_SIZE);
        const padding = 20.0;
        const playAgainRectWidth = @as(f32, @floatFromInt(playAgainTextWidth)) + (padding * 2.0);
        const playAgainRectHeight = @as(f32, @floatFromInt(Config.FONT_SIZE)) + (padding * 2.0);
        const play_again_y_offset = 80;
        rl.drawText(
            playAgainText,
            @intFromFloat(@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0 - @as(f32, @floatFromInt(playAgainTextWidth)) / 2.0),
            @intFromFloat(@as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0 - (Config.FONT_SIZE / 2.0) + play_again_y_offset),
            Config.FONT_SIZE,
            rl.Color.green,
        );
        rl.drawRectangleLines(
            @intFromFloat(@as(f32, @floatFromInt(@divFloor(rl.getScreenWidth(), 2))) - (playAgainRectWidth / 2.0)),
            @intFromFloat(@as(f32, @floatFromInt(@divFloor(rl.getScreenHeight(), 2))) - (playAgainRectHeight / 2.0) + play_again_y_offset),
            @intFromFloat(playAgainRectWidth),
            @intFromFloat(playAgainRectHeight),
            rl.Color.green,
        );
    }

    pub fn update(self: *@This()) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.left) and
            rl.checkCollisionPointRec(rl.getMousePosition(), rl.Rectangle{
                .x = @as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0 - 200.0 / 2.0,
                .y = @as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0 + 50.0,
                .width = 200.0,
                .height = 50.0,
            }))
        {
            self.playAgain = true;
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

    // Get all screens ready
    var startMenu = StartMenu.init();

    var game_state = try GameState.init(allocator, rand, .{});
    defer game_state.deinit();
    game_state.attachSelfToEntities();
    game_state.validate();

    var gameOverScreen: GameOver = undefined;

    // Set active screen to display first
    var activeScreen = ActiveScreen{ .start_menu = &startMenu };

    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // game / window loop
    // When the active screen is game_state, game_state.update() and .draw() will be called each loop.
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        switch (activeScreen) {
            .start_menu => |menu| {
                if (menu.startPressed) {
                    activeScreen = ActiveScreen{ .game_loop = &game_state };
                } else {
                    menu.update();
                    menu.draw();
                }
            },
            .game_loop => |gameState| {
                if (gameState.game_over) {
                    gameOverScreen = GameOver.init(gameState.score);
                    activeScreen = ActiveScreen{ .game_over = &gameOverScreen };
                } else {
                    gameState.update();
                    gameState.draw();
                }
            },
            .game_over => |game_over| {
                game_over.update();
                game_over.draw();
                if (game_over.playAgain) {
                    game_state.reset();
                    startMenu.startPressed = false;
                    activeScreen = ActiveScreen{ .start_menu = &startMenu };
                }
            },
        }
    }
}
