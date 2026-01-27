const std = @import("std");
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

    pub fn draw(self: Rect, color: rl.Color) void {
        rl.drawRectangle(@intFromFloat(self.x), @intFromFloat(self.y), @intFromFloat(self.width), @intFromFloat(self.height), color);
    }
};

const PlayerConfig = struct {
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

    pub fn toGame(self: @This()) Player {
        return Player.fromPlayerConfig(self);
    }
};

const BulletConfig = struct {
    width: f32,
    height: f32,

    pub fn init(width: f32, height: f32) @This() {
        return .{ .width = width, .height = height };
    }

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar = 1.0 / 100.0;
        return .{
            .width = screenWidth * defaultScalar,
            .height = screenWidth * defaultScalar * 2.0,
        };
    }
};
const ShieldConfig = struct {
    width: f32,
    height: f32,
    spacing: f32,

    pub fn fromScreenDims(screenWidth: f32) @This() {
        const defaultScalar = 1.0 / 10.0;
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
    pub fn fromScreenDims(screenWidth: i32, screenHeight: i32) @This() {
        const screenHeightF: f32 = @floatFromInt(screenHeight);
        const screenWidthF: f32 = @floatFromInt(screenWidth);
        return .{
            .screenWidth = screenWidth,
            .screenHeight = screenHeight,
            .playerConfig = PlayerConfig.fromScreenDims(screenWidthF, screenHeightF),
            .bulletConfig = BulletConfig.fromScreenDims(screenWidthF),
            .shieldConfig = ShieldConfig.fromScreenDims(screenWidthF),
            .invaderConfig = InvaderConfig.fromScreenDims(screenWidthF),
        };
    }
};

const Player = struct {
    width: f32,
    height: f32,
    posX: f32,
    posY: f32,
    speed: f32,

    pub fn fromPlayerConfig(playerConfig: PlayerConfig) @This() {
        return .{
            .width = playerConfig.width,
            .height = playerConfig.height,
            .posX = playerConfig.startX,
            .posY = playerConfig.startY,
            .speed = playerConfig.speed,
        };
    }

    pub fn draw(self: @This()) void {
        self.rect().draw(rl.Color.blue);
    }

    pub fn rect(self: @This()) Rect {
        return Rect{
            .height = self.height,
            .width = self.width,
            .x = self.posX,
            .y = self.posY,
        };
    }

    pub fn update(self: *@This(), gameConfig: GameConfig) void {
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            self.posX -= self.speed;
        }
        if (rl.isKeyDown(rl.KeyboardKey.right)) {
            self.posX += self.speed;
        }
        self.posX = std.math.clamp(self.posX, 0, @as(f32, @floatFromInt(gameConfig.screenWidth)) - self.width);
    }
};

const GameState = struct {
    gameConfig: GameConfig,
    isStartMenu: bool,
    player: Player,

    pub fn init(gameConfig: GameConfig) @This() {
        return .{
            .gameConfig = gameConfig,
            .isStartMenu = true,
            .player = gameConfig.playerConfig.toGame(),
        };
    }

    pub fn update(self: *@This()) void {
        if (!self.isStartMenu) {
            self.player.update(self.gameConfig);
        }
    }

    pub fn draw(self: @This()) void {
        if (!self.isStartMenu) {
            self.player.draw();
        }
    }
};

const ActiveScreenTag = enum {
    start_menu,
    // game_loop,
};

const ActiveScreen = union(ActiveScreenTag) {
    start_menu: StartMenu,
    // game_loop: GameState,

    pub fn init(startMenu: StartMenu) @This() {
        return .{
            .start_menu = startMenu,
        };
    }

    pub fn update(self: *@This()) void {
        std.debug.print("mousedOver?: {}\n", .{self.start_menu.isMouseOnStartRect()});
    }

    pub fn draw(self: @This()) void {
        switch (self) {
            .start_menu => |value| value.draw(),
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

    pub fn init(gameConfig: GameConfig) @This() {
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
            .startTextX = @intFromFloat(@as(f32, @floatFromInt(gameConfig.screenWidth)) / 2.0 -  (@as(f32, @floatFromInt(startTextWidth)) / 2.0)),
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

    // init window
    const screenWidth = 1280;
    const screenHeight = 760;
    rl.initWindow(screenWidth, screenHeight, "Zig Invaderz");

    const gameConfig = GameConfig.fromScreenDims(screenWidth, screenHeight);
    const startMenu = StartMenu.init(gameConfig);

    var activeScreen = ActiveScreen{ .start_menu = startMenu };

    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // window loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        activeScreen.update();
        activeScreen.draw();

        rl.endDrawing();
    }
}
