module GraytoBinary #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] G,
    output reg  [WIDTH-1:0] B
);
    always @(*) begin
        case (G)
            4'b0000: B = 4'd0;
            4'b0001: B = 4'd1;
            4'b0011: B = 4'd2;
            4'b0010: B = 4'd3;
            4'b0110: B = 4'd4;
            4'b0100: B = 4'd5;
            4'b0101: B = 4'd6;
            4'b0111: B = 4'd7;
            4'b1111: B = 4'd8;
            4'b1011: B = 4'd9;
            4'b1001: B = 4'd10;
            4'b1000: B = 4'd11;
            default: B = 4'd0;
        endcase
    end
endmodule
