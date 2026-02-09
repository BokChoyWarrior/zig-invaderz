const Vec2 = @import("./main.zig").Vec2;

pub fn downwardsLinear(t: u32) Vec2 {
    _ = t;
    // constant downwards speed of 5
    return Vec2.init(0.0, 5.0);
}

pub fn upwardsLinear(t: u32) Vec2 {
    _ = t;
    // constant upwards speed of 5
    return Vec2.init(0.0, -10.0);
}

pub fn downwardsSwerving(t: u32) Vec2 {
    // swerving downwards
    return Vec2.init(@sin((@as(f32, @floatFromInt(t)) * 0.1)) * 5.0, 2.5);
}
