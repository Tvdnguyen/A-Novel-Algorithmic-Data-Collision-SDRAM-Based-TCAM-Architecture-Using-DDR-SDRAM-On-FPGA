//////////////////////////////////////////////////////////
//	Category	  : Logic Design (DataPath Orientator)	//
//	Name File     : fragmentation.v     			    //
//	Author        : Dang Tieu Binh                      //
//	Email         : dangtieubinh0207@gmail.com          //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		//
//	Start design  : 09.03.2022                          //
//	Last revision : 14.03.2022                          //
//////////////////////////////////////////////////////////

module fragmentation (
        // clock and reset
        input                       clk
       ,input                       reset
        
        // key
       ,input       [    KWID-1:0]  i_key
       ,output reg  [ADDR_WID-1:0]  o_fragment_key
       
        // control signals
       ,input                       i_load
       ,input                       i_shift
	);

// ===================================================
//	 Parameters
// ===================================================	
    parameter   DATA_BITS = 10; // Key length
    parameter   FRAGMENTS = 5;	// Number of fragments
    parameter   FRAG_BITS = 3;	// Number of bits represent for number of fragments
    parameter   IDWID     = 2;  // ID width
    parameter   MASKWID   = 5;

// ===================================================
//	 Local Parameters
// ===================================================
    localparam  FRAG_WID  = (DATA_BITS/FRAGMENTS);
    localparam  ADDR_WID  = FRAG_BITS+FRAG_WID;
    localparam  PRIOWID   = IDWID;
    localparam  KWID      = DATA_BITS;
    localparam  SEGWID    = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY
	
// ===================================================
//	 Logic Declarations
// ===================================================
    wire [FRAG_WID-1:0] zeros;
    assign zeros = {FRAG_WID{1'b0}};
    
    reg [     KWID-1:0] shift_register;
    reg [FRAG_BITS-1:0] prefix_address;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin
            o_fragment_key <= 0;		
            shift_register <= 0;
            prefix_address <= 0;
        end 
        
        // load == 1
        else if (i_load) begin 
            shift_register <= i_key;
            prefix_address <= 0;
        end
        
        // shift == 1
        else if (i_shift) begin
            prefix_address <= prefix_address + 1;
            o_fragment_key <= {prefix_address, shift_register[FRAG_WID-1:0]};
            shift_register <= {zeros, shift_register[KWID-1:FRAG_WID]};
        end 
        
        // catch-all
        else begin
            prefix_address <= prefix_address;
            shift_register <= shift_register; 
        end
    end 
endmodule