module BinarytoGray #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] B,
    output reg  [WIDTH-1:0] G
);
    // 12-state cyclic Gray sequence for a depth-6 FIFO.
    always @(*) begin
        case (B)
            4'd0:  G = 4'b0000;
            4'd1:  G = 4'b0001;
            4'd2:  G = 4'b0011;
            4'd3:  G = 4'b0010;
            4'd4:  G = 4'b0110;
            4'd5:  G = 4'b0100;
            4'd6:  G = 4'b0101;
            4'd7:  G = 4'b0111;
            4'd8:  G = 4'b1111;
            4'd9:  G = 4'b1011;
            4'd10: G = 4'b1001;
            4'd11: G = 4'b1000;
            default: G = 4'b0000;
        endcase
    end
endmodule
