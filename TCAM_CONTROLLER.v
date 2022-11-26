//////////////////////////////////////////////////////////
//	Category	  : Logic Design (TCAM)					//
//	Name File     : tcam_controller.v  (Top Level)      //
//	Author        : Dang Tieu Binh                      //
//	Email         : dangtieubinh0207@gmail.com          //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		//
//	Start design  : 22.03.2022                          //
//	Last revision : 06.10.2022							//
//			** DO NOT DELETE THIS CONTRIBUTION **		//
//////////////////////////////////////////////////////////

module TCAM_CONTROLLER  (
		// clock and reset 
        input                       CLK
       ,input                       RESET
       
        // CAM's i/o
       ,input                       SEARCH
       ,input                       SETTING
       ,input     [    KWID-1:0 ]   KEY
       ,input     [   IDWID-1:0 ]   SETTING_ID
       ,input     [ MASKWID-1:0 ]   SETTING_MASKID
       ,input     [ PRIOWID-1:0 ]   SETTING_PRIORITY
       ,output    [   IDWID-1:0 ]   RULEID
       ,output                      SETTING_COMPLETE
       ,output                      SEARCH_COMPLETE
       ,output                      MISMATCH
       
        // SDRAM Controller's i/o
       ,input     [   SEGWID-1:0 ]  SDRAM_READDATA
       ,input                       SDRAM_WAITREQUEST
       ,input                       SDRAM_READDATAVALID
       ,output                      SDRAM_READ
       ,output                      SDRAM_WRITE
       ,output    [ ADDR_WID-1:0 ]  SDRAM_ADDRESS
       ,output    [   SEGWID-1:0 ]  SDRAM_WRITEDATA
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
    reg                  search_en_sync1;
    reg                  setting_en_sync1;
    reg  [   KWID-1:0]	 key_sync1;
    reg  [  IDWID-1:0]	 setting_id_sync1;
    reg  [MASKWID-1:0]   setting_maskid_sync1;
    reg  [PRIOWID-1:0]   setting_priority_sync1;
    
    always @(posedge CLK or posedge RESET)
    begin 
        if (RESET) begin 
            key_sync1              <= 0;
            search_en_sync1        <= 0;
            setting_en_sync1       <= 0;
            setting_id_sync1       <= 0;
            setting_maskid_sync1   <= 0;
            setting_priority_sync1 <= 0;
        end 
        else begin
            key_sync1		       <= KEY;
            search_en_sync1        <= SEARCH;
            setting_en_sync1       <= SETTING;
            setting_id_sync1       <= SETTING_ID;
            setting_maskid_sync1   <= SETTING_MASKID;
            setting_priority_sync1 <= SETTING_PRIORITY;
        end
    end
    
// ===================================================
//	 Logic Declarations
// ===================================================
    // Interconnections
    wire                    w_cntl_searchcomplete;	
    wire                    w_cntl_searchdatavalid;
    wire    [SEGWID-1:0] 	w_confirm_segment;
    wire                    w_compare_complete;
    
    // -----------------------------------------------
    //	 Segmentation
    // -----------------------------------------------
    
    segment_engine  
    #( 
        .DATA_BITS                  ( DATA_BITS ), 
        .FRAGMENTS                  ( FRAGMENTS ), 
        .FRAG_BITS                  ( FRAG_BITS ), 
        .IDWID                      ( IDWID     ),
        .MASKWID                    ( MASKWID   )
    ) 
    SEGMENTATION_INST  // Instance Name
    (
        // clock and reset
        .clk                        ( CLK                    ),
        .reset                      ( RESET                  ), 
        
        // CAM's i/o
        .i_search                   ( search_en_sync1        ),
        .i_setting                  ( setting_en_sync1       ),
        .i_key                      ( key_sync1              ),
        .i_setting_id               ( setting_id_sync1       ),
        .i_setting_maskid           ( setting_maskid_sync1   ),
        .i_setting_priority         ( setting_priority_sync1 ),
        
        // Setting/Searching complete notify
        .o_search_complete          ( w_cntl_searchcomplete  ),
        .o_setting_complete			( SETTING_COMPLETE       ),
        
        // Search Data Valid notify 
        .o_cntl_m0_searchdatavalid  ( w_cntl_searchdatavalid ),
    
        // SDRAM Controller's i/o
        .i_sdram_readdata           ( SDRAM_READDATA         ),
        .i_sdram_waitrequest        ( SDRAM_WAITREQUEST      ),
        .i_sdram_readdatavalid		( SDRAM_READDATAVALID    ),
        .o_sdram_read               ( SDRAM_READ             ),
        .o_sdram_write              ( SDRAM_WRITE            ),
        .o_sdram_address            ( SDRAM_ADDRESS          ),
        .o_sdram_writedata          ( SDRAM_WRITEDATA        )
    );
    
    // -----------------------------------------------
    //	 Mask Process
    // -----------------------------------------------
    
    wire [  IDWID-1:0] w_mask_confirm_id;
    wire [MASKWID-1:0] w_mask_confirm_maskid;
    wire [PRIOWID-1:0] w_mask_confirm_priority;
    wire [   KWID-1:0] w_mask_confirm_key;
    wire               w_mask_confirm_id_update;
    wire               w_mask_complete;
    
    mask_engine 
    #( 
        .DATA_BITS                  ( DATA_BITS ), 
        .FRAGMENTS                  ( FRAGMENTS ), 
        .FRAG_BITS                  ( FRAG_BITS ), 
        .IDWID                      ( IDWID     ),
        .MASKWID                    ( MASKWID   )
    )
    MASK_ENGINE_INST  // Instance Name
    (
        // clock and reset 
        .clk                        ( CLK                      ),
        .reset                      ( RESET                    ),
        
        // data i/o
        .i_sdram_readdata           ( SDRAM_READDATA           ),
        .o_id                       ( w_mask_confirm_id        ),
        .o_maskid                   ( w_mask_confirm_maskid    ),
        .o_confirm_key              ( w_mask_confirm_key       ),
        .o_priority                 ( w_mask_confirm_priority  ),
        
        // control i/o
        .i_cntl_s0_searchdatavalid  ( w_cntl_searchdatavalid   ),
        .i_segment_complete         ( w_cntl_searchcomplete    ),
        .o_id_update                ( w_mask_confirm_id_update ),
        .o_mask_complete            ( w_mask_complete          )
    );
    
    // -----------------------------------------------
    //	 Confirmation
    // -----------------------------------------------
    
    wire [KWID-1:0] w_pp_key6;
    ffxkclkx #(6,KWID) pp_search_key (CLK,RESET,key_sync1,w_pp_key6);
    
    wire [  IDWID-1:0]  w_confirm_prio_ruleid;
    wire [PRIOWID-1:0]  w_confirm_prio_priority;
    wire                w_confirm_complete;
    wire                w_confirm_prio_valid;
    
    confirm_engine 
    #( 
        .DATA_BITS                  ( DATA_BITS ), 
        .FRAGMENTS                  ( FRAGMENTS ), 
        .FRAG_BITS                  ( FRAG_BITS ), 
        .IDWID                      ( IDWID     ),
        .MASKWID                    ( MASKWID   )
    )
    CONFIRM_ENGINE_INST  // Instance Name
    (
        // clock and reset 
        .clk                        ( CLK                      ),
        .reset                      ( RESET                    ),
        
        // data i/o
        .i_key                      ( w_pp_key6                ),
        .i_id                       ( w_mask_confirm_id        ),
        .i_maskid                   ( w_mask_confirm_maskid    ),
        .i_priority                 ( w_mask_confirm_priority  ),
        .i_confirm_key              ( w_mask_confirm_key       ),
        .o_confirm_ruleid           ( w_confirm_prio_ruleid    ),
        .o_confirm_priority         ( w_confirm_prio_priority  ),
    
        // control i/o
        .i_id_update                ( w_mask_confirm_id_update ),    // inform new ID comes
        .i_mask_complete            ( w_mask_complete          ),
        .o_confirm_complete         ( w_confirm_complete       ), 
        .o_confirm_valid            ( w_confirm_prio_valid     )
    );
    
    
    // -----------------------------------------------
    //	 Address Selection
    // -----------------------------------------------
    
    priority_engine 
    #( 
        .DATA_BITS                  ( DATA_BITS ), 
        .FRAGMENTS                  ( FRAGMENTS ), 
        .FRAG_BITS                  ( FRAG_BITS ), 
        .IDWID                      ( IDWID     ),
        .MASKWID                    ( MASKWID   )
    )
    PRIORITY_ENGINE_INST   // Instance Name
    (   
        // clock and reset 
        .clk                        ( CLK                     ),
        .reset                      ( RESET                   ),
        
        // data i/o
        .i_confirm_ruleid           ( w_confirm_prio_ruleid   ),
        .i_confirm_priority         ( w_confirm_prio_priority ),
        .o_final_id                 ( RULEID                  ), 
        .o_mismatch                 ( MISMATCH                ),
    
        // control i/o                
        .i_confirm_valid            ( w_confirm_prio_valid    ),
        .i_confirm_complete         ( w_confirm_complete      ),
        .o_priority_complete        ( SEARCH_COMPLETE         )
    );
endmodule