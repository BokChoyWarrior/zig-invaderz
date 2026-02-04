const rl = @import("raylib");

pub const Player = struct {
    width: f32,
    height: f32,
    startX: f32,
    startY: f32,
    speed: f32,

    pub fn init(width: f32, height: f32, startX: f32, startY: f32, speed: f32) @This() {
        return .{
            .width = width,
            .height = height,
            .startX = startX,
            .startY = startY,
            .speed = speed,
        };
    }

    pub fn fromScreenDims(screenWidth: f32, screenHeight: f32) @This() {
        const defaultSizeModifier = 1.0 / 50.0;
        const width = screenWidth * defaultSizeModifier * 1 / 2;
        return .{
            .width = width,
            .height = screenHeight * defaultSizeModifier,
            .startX = (screenWidth / 2.0) + (width / 2.0),
            .startY = screenHeight * (1.0 - defaultSizeModifier),
            .speed = width,
        };
    }
};

pub const Bullet = struct {
    width: f32,
    height: f32,
    speed: f32,

    pub fn init(width: f32, height: f32, speed: f32) @This() {
        return .{
            .width = width,
            .height = height,
            .speed = speed,
        };
    }

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const bullet_speed = 5.0;
        const defaultScalar = 1.0 / 500.0;
        // specifically we want a square bullet - so we use the width to set both dimensions
        return .{ .width = screenWidth * defaultScalar, .height = screenWidth * defaultScalar, .speed = screenWidth * defaultScalar * bullet_speed };
    }
};

pub const Shield = struct {
    width: f32,
    height: f32,
    max_health: u8,
    // space from one shield x to next x
    spacing_factor: f32,
    colour: rl.Color,

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar = 1.0 / 20.0;
        const width = screenWidth * defaultScalar;
        return .{
            .width = width,
            .height = width * 0.5,
            .max_health = 5,
            .spacing_factor = 3.0,
            .colour = rl.Color.blue,
        };
    }
};

pub const Invader = struct {
    width: f32,
    height: f32,
    colour: rl.Color,
    speed: f32,

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar: f32 = 1.0 / 30.0;
        return .{
            .width = screenWidth * defaultScalar,
            .height = screenWidth * defaultScalar * 0.5,
            .colour = rl.Color.red,
            .speed = 5,
        };
    }
};

pub const BulletPool = struct {
    max_bullets: u8,
    bullet_config: Bullet,

    pub fn init(max_bullets: u8, bullet_config: Bullet) @This() {
        return .{
            .max_bullets = max_bullets,
            .bullet_config = bullet_config,
        };
    }
};

pub const Game = struct {
    screenWidth: i32,
    screenHeight: i32,
    playerConfig: Player,
    playerBulletPoolConfig: BulletPool,
    shieldConfig: Shield,
    invaderConfig: Invader,

    pub fn fromScreenDims(screenWidth: i32, screenHeight: i32) @This() {
        const screenHeightF: f32 = @floatFromInt(screenHeight);
        const screenWidthF: f32 = @floatFromInt(screenWidth);
        return .{
            .screenWidth = screenWidth,
            .screenHeight = screenHeight,
            .playerConfig = Player.fromScreenDims(screenWidthF, screenHeightF),
            .playerBulletPoolConfig = BulletPool.init(10, Bullet.fromScreenDims(screenWidthF)),
            .shieldConfig = Shield.fromScreenDims(screenWidthF),
            .invaderConfig = Invader.fromScreenDims(screenWidthF),
        };
    }
};
