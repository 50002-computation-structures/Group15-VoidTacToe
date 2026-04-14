module Reduction (A, Y1, Y2, Y3, Y4, Y5, Y6);
input [3:0] A;
output Y1, Y2, Y3, Y4, Y5, Y6;
reg Y1, Y2, Y3, Y4, Y5, Y6;
always @(A)
    begin
        Y1=&A; //reduction AND
        Y2=|A; //reduction OR
        Y3=~&A; //reduction NAND
        Y4=~|A; //reduction NOR
        Y5=^A; //reduction XOR
        Y6=~^A; //reduction XNOR
    end
endmodule