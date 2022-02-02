local vec3 = require "vec3"

local function transformVec(vec, matrix)
  return vec3.new(
    vec.x * matrix[1] + vec.y * matrix[5] + vec.z * matrix[9] + matrix[13],
    vec.x * matrix[2] + vec.y * matrix[6] + vec.z * matrix[10] + matrix[14],
    vec.x * matrix[3] + vec.y * matrix[7] + vec.z * matrix[11] + matrix[15]
  )
end

-- calculate distance from point A to closest point on line BC
local function distanceToLine(A, B, C)
  return vec3.length(vec3.cross(A - B, C - B)) / vec3.length(C - B)
end

return {
  transformVec = transformVec,
  distanceToLine = distanceToLine
}