// const std = @import("std");
const zig_invaders = @import("zig_invaders");
const rl = @import("raylib");

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
};

const PlayerConfig = struct {
    width: f32,
    height: f32,
    startY: f32,

    pub fn init(width: f32, height: f32, startY: f32) @This() {
        return .{
            .width = width,
            .height = height,
            .startY = startY,
        };
    }

    pub fn fromScreenDims(screenWidth: f32, screenHeight: f32) @This() {
        const defaultSizeModifier = 1 / 50;
        const width = screenWidth * defaultSizeModifier / 2;
        return .{
            .width = width,
            .height = screenHeight * defaultSizeModifier,
            .startY = screenHeight * (1 - defaultSizeModifier),
        };
    }
};

const BulletConfig = struct {
    width: f32,
    height: f32,

    pub fn init(width: f32, height: f32) @This() {
        return .{ .width = width, .height = height };
    }

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar = 1 / 100;
        return .{
            .width = screenWidth * defaultScalar,
            .height = screenWidth * defaultScalar * 2,
        };
    }
};
const ShieldConfig = struct {
    width: f32,
    height: f32,
    spacing: f32,

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar = 1 / 10;
        return .{
            .width = screenWidth * defaultScalar,
            .height = screenWidth * defaultScalar,
            .spacing = screenWidth * defaultScalar,
        };
    }
};

const InvaderConfig = struct {
    width: f32,
    height: f32,
    spacingX: f32,
    spacingY: f32,

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar = 1 / 30;
        return .{
            .width = screenWidth * defaultScalar * 2,
            .height = screenWidth * defaultScalar,
            .spacingX = screenWidth * defaultScalar,
            .spacingY = screenWidth * defaultScalar,
        };
    }
};

const GameConfig = struct {
    screenWidth: i32,
    screenHeight: i32,
    playerConfig: PlayerConfig,
    bulletConfig: BulletConfig,
    shieldConfig: ShieldConfig,
    invaderConfig: InvaderConfig,
    pub fn fromScreenDims(screenWidth: f32, screenHeight: f32) @This() {
        return .{
            .screenWidth = screenWidth,
            .screenHeight = screenHeight,
            .playerConfig = PlayerConfig.fromScreenDims(screenWidth, screenHeight),
            .bulletConfig = BulletConfig.fromScreenDims(screenWidth),
            .shieldConfig = ShieldConfig.fromScreenDims(screenWidth),
            .invaderConfig = InvaderConfig.fromScreenDims(screenWidth),
        };
    }
};

pub fn main() !void {

    // init window
    const screenWidth = 1280;
    const screenHeight = 760;

    rl.initWindow(screenWidth, screenHeight, "Zig Invaderz");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // window loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        const splashFontSize = screenHeight / 10;
        const splashText = "Zig Invaderz";
        const splashTextWidth = rl.measureText(splashText, splashFontSize);
        const splashPosX = screenWidth / 2 - @divFloor(splashTextWidth, 2);
        const splashPosY = screenHeight / 2 - splashFontSize / 2;
        rl.drawText(splashText, splashPosX, splashPosY, splashFontSize, rl.Color.green);

        rl.endDrawing();
    }
}
