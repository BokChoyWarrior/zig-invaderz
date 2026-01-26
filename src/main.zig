// const std = @import("std");
const zig_invaders = @import("zig_invaders");
const rl = @import("raylib");

const Rect = struct {
    x: f32,
    y: f32,
    width: u32,
    height: u32, // used unsigned 32 bit here to see if it works. Original tutorial used f32

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
};

const BulletConfig = struct {
    width: f32,
    height: f32
};
const ShieldConfig = struct {
    width: f32,
    height: f32,
    spacing: f32
};

const InvaderConfig = struct {
    width: f32,
    height: f32,
    spacingX: f32,
    spacingY: f32
};

const GameConfig = struct {
    screenWidth: i32,
    screenHeight: i32,
    playerConfig: PlayerConfig,
    bulletConfig: BulletConfig,
    shieldConfig: ShieldConfig,
    invaderConfig: InvaderConfig
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
