////////////////////////////////////////////////////////////////////////////////
//
// Ho CHi Minh City University of Technology
//
// Filename     : ffxkclkx.v
// Description  : .pipi data bus n x bit
//
// Author       : .
// Created On   : Tue Dec 15 08:15:08 2009
// History (Date, Changed By)
//
////////////////////////////////////////////////////////////////////////////////

module ffxkclkx
    (
     clk,
     rst,
     idat,
     odat
     );

////////////////////////////////////////////////////////////////////////////////
// Parameter declarations
parameter           K = 3;  //delay 3 clock cycle
parameter           W = 10; //width

////////////////////////////////////////////////////////////////////////////////
// Port declarations
input               clk;
input               rst;
input [W-1:0]       idat;
output [W-1:0]      odat;
  
////////////////////////////////////////////////////////////////////////////////
// Output declarations
wire [W-1:0]        odat;

////////////////////////////////////////////////////////////////////////////////
// Local logic and instantiation

generate
    genvar bit_idx;
for (bit_idx=0;bit_idx<W;bit_idx=bit_idx+1'b1)
    begin: i_bit
    ffxkclk #(K)    flxodat (clk,rst,idat[bit_idx],odat[bit_idx]);
    end
endgenerate

endmodule 
