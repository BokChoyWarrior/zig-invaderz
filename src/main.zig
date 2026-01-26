// const std = @import("std");
const zig_invaders = @import("zig_invaders");
const rl = @import("raylib");

pub fn main() !void {

    // init window
    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "Zig Invaderz");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // window loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        const splashFontSize = screenHeight / 10;
        const splashText = "Zig Invaderz";
        const splashTextWidth = rl.measureText(splashText,  splashFontSize);
        const splashPosX = screenWidth / 2 - @divFloor(splashTextWidth, 2);
        const splashPosY = screenHeight / 2 - splashFontSize / 2;
        rl.drawText(splashText, splashPosX, splashPosY, splashFontSize, rl.Color.green);

        rl.endDrawing();
    }
}
