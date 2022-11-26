//////////////////////////////////////////////////////////
//  Category      : Logic Design (TCAM)                 //
//  Name File     : segment_engine.v                   //
//  Author        : Dang Tieu Binh                      //
//  Email         : dangtieubinh0207@gmail.com          //
//  Standard      : IEEE 1800—2009(Verilog-2009)        //
//  Start design  : 05.10.2022                          //
//  Last revision : 06.10.2022                          //
//          ** DO NOT DELETE THIS CONTRIBUTION **       //
//////////////////////////////////////////////////////////

module segment_engine (
        // clock and reset 
        input 					clk
       ,input 					reset
       
        // CAM's i/o
       ,input                   i_search
       ,input                   i_setting
       ,input   [   KWID-1:0]   i_key
       ,input   [MASKWID-1:0]   i_setting_maskid
       ,input   [PRIOWID-1:0]   i_setting_priority
       ,input   [  IDWID-1:0]   i_setting_id
       
        // Setting/Searching complete notify
       ,output                  o_search_complete
       ,output                  o_setting_complete
       
        // Search Data Valid notify
       ,output                  o_cntl_m0_searchdatavalid
       
        // SDRAM Controller's i/o
       ,input   [ SEGWID-1:0]   i_sdram_readdata
       ,input                   i_sdram_waitrequest
       ,input                   i_sdram_readdatavalid
       ,output                  o_sdram_read
       ,output                  o_sdram_write
       ,output  [ADDR_WID-1:0]  o_sdram_address
       ,output  [  SEGWID-1:0]  o_sdram_writedata
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
//	 Input Registered
// ===================================================
	reg 				search_en_sync1;
	reg 				setting_en_sync1;
	reg   [   KWID-1:0]	key_sync1;
	reg   [  IDWID-1:0]	setting_id_sync1;
	reg	  [MASKWID-1:0]	setting_maskid_sync1;
    reg   [PRIOWID-1:0] setting_priority_sync1;
	
	always @(posedge clk or posedge reset)
	begin 
		if (reset) begin 
			key_sync1 		  	   <= 0;
			search_en_sync1   	   <= 0;
			setting_en_sync1  	   <= 0;
			setting_id_sync1  	   <= 0;
			setting_maskid_sync1   <= 0;
            setting_priority_sync1 <= 0;
		end 
		else begin
			key_sync1		       <= i_key;
			search_en_sync1        <= i_search;
			setting_en_sync1       <= i_setting;
			setting_id_sync1       <= i_setting_id;
			setting_maskid_sync1   <= i_setting_maskid;
            setting_priority_sync1 <= i_setting_priority;
		end
	end 

// ===================================================
//	 Logic Declarations
// ===================================================
    // interconnect signals
    wire					w_cntl_load;
    wire 					w_cntl_modify;
    wire					w_cntl_shift;
    wire 					w_cntl_search;
    wire 					w_cntl_modify_done;
    wire   [ADDR_WID-1:0]	w_fragment_key;
    
    // -----------------------------------------------
    //	Fragmentation 
    // -----------------------------------------------
    
    fragmentation  
    #( 
        .DATA_BITS                 ( DATA_BITS          ), 
        .FRAGMENTS                 ( FRAGMENTS          ), 
        .FRAG_BITS                 ( FRAG_BITS          ), 
        .IDWID                     ( IDWID              ),
        .MASKWID                   ( MASKWID            )
    )
    FRAGMENT_INST // Instance Name
    (
        // clock and reset
        .clk	                   ( clk                ),
        .reset                     ( reset              ),
        
        // i_key
        .i_key                     ( key_sync1          ),
        .o_fragment_key            ( w_fragment_key     ),
        
        // control signals
        .i_load				       ( w_cntl_load        ),
        .i_shift                   ( w_cntl_shift       )
    );
    
    // -----------------------------------------------
    //	 Segment Controller
    // -----------------------------------------------
    
    segment_controller 
    #( 
        .FRAGMENTS                 ( FRAGMENTS                 )  
    )	
    SEGMENT_CONTROLLER_INST  // Instance Name
    (
        // clock and reset
        .clk                       ( clk                       ),
        .reset                     ( reset                     ), 
    
        // i_setting enable		   
        .i_search_enable           ( search_en_sync1           ),
        .i_setting_enable          ( setting_en_sync1          ),
    
        // control SDRAM i/o       
        .o_sdram_read              ( o_sdram_read              ),
        .o_sdram_write             ( o_sdram_write             ),
        .i_sdram_waitrequest       ( i_sdram_waitrequest       ),
        .i_sdram_readdatavalid     ( i_sdram_readdatavalid     ),
        
        // control DATAPATH i/o
        .o_cntl_m0_load            ( w_cntl_load               ),
        .o_cntl_m0_modify          ( w_cntl_modify             ),
        .o_cntl_m0_shift           ( w_cntl_shift              ),
        .i_cntl_m0_modify_done     ( w_cntl_modify_done        ),
        .o_cntl_m0_searchdatavalid ( o_cntl_m0_searchdatavalid ),
        
        // Setting complete notify 
        .o_search_complete         ( o_search_complete         ),
        .o_setting_complete        ( o_setting_complete        )
    );
    
    // -----------------------------------------------
    //	 Segment Datapath
    // -----------------------------------------------
    segment_datapath  
    #( 
        .DATA_BITS                 ( DATA_BITS              ), 
        .FRAGMENTS                 ( FRAGMENTS              ), 
        .FRAG_BITS                 ( FRAG_BITS              ), 
        .IDWID                     ( IDWID                  ),
        .MASKWID                   ( MASKWID                )
    )	
    SEGMENT_DATAPATH_INST // Instance Name
    (
        // clock and reset
        .clk					   ( clk                    ),
        .reset					   ( reset                  ), 
        
        // i_setting i/o
        .i_setting_id		       ( setting_id_sync1       ),
        .i_setting_key		       ( key_sync1              ),
        .i_setting_maskid		   ( setting_maskid_sync1   ),
        .i_setting_priority        ( setting_priority_sync1 ),
        .i_fragment_key            ( w_fragment_key         ),
        
        // SDRAM Controller
        .i_sdram_readdata          ( i_sdram_readdata       ),		
        .o_sdram_writedata		   ( o_sdram_writedata      ),
        .o_sdram_segment_address   ( o_sdram_address        ), 
        
        // control signal from CONTROLLER
        .i_cntl_s0_modify          ( w_cntl_modify          ),
        .o_cntl_s0_modify_done     ( w_cntl_modify_done     )
    );
endmodule