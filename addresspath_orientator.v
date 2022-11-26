//////////////////////////////////////////////////////////
//	Category	  : Logic Design (Segment DataPath)		//
//	Name File     : addresspath_orientator.v 			//
//	Author        : Dang Tieu Binh                      //
//	Email         : dangtieubinh0207@gmail.com          //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		//
//	Start design  : 09.03.2021                          //
//	Last revision : 25.03.2022                          //
//////////////////////////////////////////////////////////

module addresspath_orientator (
        // clock and reset
        input						clk,
        input 						reset, 
        
        // commmon i/o
        input		[ADDR_WID-1:0]	i_fragment_key,
        output 	reg [ADDR_WID-1:0]	o_sdram_segment_address // address
	);
// ===================================================
//	 Parameters
// ===================================================	
    parameter	DATA_BITS = 10; // Key length
    parameter 	FRAGMENTS = 5;	// Number of fragments
    parameter 	FRAG_BITS = 3;	// Number of bits represent for number of fragments

// ===================================================
//	 Local Parameters
// ===================================================
    localparam 	FRAG_WID  = (DATA_BITS/FRAGMENTS);
    localparam 	ADDR_WID  = FRAG_BITS+FRAG_WID;
	
// ===================================================
//	 Logic Declarations
// ===================================================
	// Fragment as address
	always @(posedge clk or posedge reset)
	begin 
		if   (reset)	o_sdram_segment_address <= 0;
		else 			o_sdram_segment_address <= i_fragment_key;
	end
endmodule