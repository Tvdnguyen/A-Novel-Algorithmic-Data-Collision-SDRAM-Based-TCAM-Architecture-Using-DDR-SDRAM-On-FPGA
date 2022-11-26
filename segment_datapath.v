//////////////////////////////////////////////////////////
//	Category	  : Logic Design (Segment Engine)		//
//	Name File     : segment_datapath.v (top level)     	//
//	Author        : Dang Tieu Binh                      //
//	Email         : dangtieubinh0207@gmail.com          //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		//
//	Start design  : 11.12.2021                          //
//	Last revision : 05.10.2022                          //
//////////////////////////////////////////////////////////

module segment_datapath (
        // clock and reset
        input                   clk
       ,input                   reset
		
        // setting i/o
       ,input   [  IDWID-1:0]   i_setting_id
       ,input   [   KWID-1:0]   i_setting_key
       ,input   [MASKWID-1:0]   i_setting_maskid
       ,input   [PRIOWID-1:0]   i_setting_priority
       
        // SDRAM i/o
       ,input   [ SEGWID-1:0]   i_sdram_readdata   // readdata
       ,output  [ SEGWID-1:0]   o_sdram_writedata  // writedata
	
        // commmon i/o
       ,input   [ADDR_WID-1:0]	i_fragment_key
       ,output  [ADDR_WID-1:0]	o_sdram_segment_address // address
       
        // control signal
       ,input                   i_cntl_s0_modify
       ,output                  o_cntl_s0_modify_done
    );

// ===================================================
//	 Parameters
// ===================================================	
    parameter	DATA_BITS = 10; // Key length
    parameter 	FRAGMENTS = 5;	// Number of fragments
    parameter 	FRAG_BITS = 3;	// Number of bits represent for number of fragments
    parameter	IDWID     = 2;  // ID width
    parameter   MASKWID   = 5;

// ===================================================
//	 Local Parameters
// ===================================================
    localparam 	FRAG_WID  = (DATA_BITS/FRAGMENTS);
    localparam 	ADDR_WID  = FRAG_BITS+FRAG_WID;
    localparam  PRIOWID   = IDWID;
    localparam 	KWID	  = DATA_BITS;
    localparam 	SEGWID	  = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY
	
// ===================================================
//	 Logic Declarations
// ===================================================
    reg [SEGWID-1:0] sdram_readdata;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            sdram_readdata <= 0;
        end
        
        // out of reset 
        else begin 
            sdram_readdata <= i_sdram_readdata;
        end 
    end 
    
    // DataPath Orientator
    addresspath_orientator 
    #( 
        .DATA_BITS                ( DATA_BITS          ), 
        .FRAGMENTS                ( FRAGMENTS          ), 
        .FRAG_BITS                ( FRAG_BITS          )
    )  
    ADDRESS_ORIENTATOR_INST  // Instance Name
    (
        // clock and reset
        .clk                      (clk),
        .reset                    (reset), 
        
        // address i/o
        .i_fragment_key           (i_fragment_key),
        .o_sdram_segment_address  (o_sdram_segment_address) // address
    );
    
    // Status Generator
    status_generator 
    #( 
        .DATA_BITS             ( DATA_BITS            ), 
        .FRAGMENTS             ( FRAGMENTS            ), 
        .FRAG_BITS             ( FRAG_BITS            ), 
        .IDWID                 ( IDWID                ),
        .MASKWID               ( MASKWID              )
    )
    STATUS_GENERATOR_INST  // Instance Name
    (
        // clock and reset
        .clk                   ( clk                   ),
        .reset                 ( reset                 ), 
        
        // setting i/o
        .i_modify              ( i_cntl_s0_modify      ),
        .i_setting_id          ( i_setting_id          ),
        .i_setting_key         ( i_setting_key         ),
        .i_setting_maskid      ( i_setting_maskid      ),  
        .i_setting_priority    ( i_setting_priority    ),
        
        // SDRAM i/o
        .i_sdram_readdata      ( sdram_readdata        ),
        .o_sdram_writedata     ( o_sdram_writedata     ), // writedata
        .o_modify_complete     ( o_cntl_s0_modify_done )
    );
endmodule

