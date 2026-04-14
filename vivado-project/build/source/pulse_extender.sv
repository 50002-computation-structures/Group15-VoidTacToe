module pulse_extender #(
    parameter CYCLES = 50  // 默认延长到50个周期
) (
    input  wire clk,
    input  wire trigger_in, // 来自 edge_detector 的 1 周期触发脉冲
    output reg  pulse_out = 0 // 持续 50 个周期的输出
);

    // 计算计数器需要的位宽
    localparam COUNT_W = $clog2(CYCLES);
    reg [COUNT_W-1:0] count = 0;

    always @(posedge clk) begin
        if (trigger_in) begin
            // 检测到触发，将计数器设为目标周期数-1，并拉高输出
            count <= CYCLES - 1;
            pulse_out <= 1'b1;
        end 
        else if (count > 0) begin
            // 触发信号消失后，开始倒计时，保持高电平
            count <= count - 1'b1;
            pulse_out <= 1'b1;
        end 
        else begin
            // 倒计时结束，恢复低电平
            pulse_out <= 1'b0;
        end
    end

endmodule