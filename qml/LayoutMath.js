.pragma library

// 布局数学:所有元素的 x 坐标都通过绝对位偏移 + 同一取整函数计算,
// 相邻分段在任意缩放级别都不会重叠或留缝。

function xForBit(bit, pxPerBit, originX) {
    return originX + Math.round(bit * pxPerBit)
}

// 字节标尺标签:十进制(0, 1, 2, ...)
function byteLabel(i) {
    return String(i)
}
