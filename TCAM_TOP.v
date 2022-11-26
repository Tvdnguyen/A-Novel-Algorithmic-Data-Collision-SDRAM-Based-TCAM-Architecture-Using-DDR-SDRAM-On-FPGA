module TCAM_TOP (
        // clock and RESET 
        input                   CLK
       ,input                   RESET
       
        // CAM's i/o
       ,input                   SEARCH
       ,input                   SETTING
       ,input                   KEY              // serial to parallel
       ,input                   SETTING_ID       // serial to parallel
       ,input                   SETTING_MASKID   // serial to parallel
       ,input                   SETTING_PRIORITY // serial to parallel
       ,output  [IDWID-1:0]     RULEID
       ,output                  SETTING_COMPLETE
       ,output                  SEARCH_COMPLETE
       ,output                  MISMATCH
        
        // DDR3 SDRAM i/o
       ,input                     DDR3_AVL_INIT
       ,input   [SDRAM_DATA-1:0]  DDR3_AVL_READDATA
       ,input                     DDR3_AVL_WAITREQUEST
       ,input                     DDR3_AVL_READDATAVALID
       ,output                    DDR3_AVL_READ
       ,output                    DDR3_AVL_WRITE
       ,output  [SDRAM_ADDR-1:0]  DDR3_AVL_ADDRESS
       ,output  [SDRAM_DATA-1:0]  DDR3_AVL_WRITEDATA
       ,output                    DDR3_AVL_BURSTCOUNT
       ,output                    DDR3_AVL_INITCOMPLETE
	);
	
// ===================================================
//	 Parameters
// ===================================================	
    parameter   DATA_BITS = 128; // Key length
    parameter   FRAGMENTS = 8;	// Number of fragments
    parameter   FRAG_BITS = 3;	// Number of bits represent for number of fragments
    parameter   IDWID     = 16;  // ID width
    parameter   MASKWID   = 18;
    
    // SDRAM
    parameter   SDRAM_ADDR = 24;
    parameter   SDRAM_DATA = 256;

// ===================================================
//	 Local Parameters
// ===================================================
    localparam  FRAG_WID  = (DATA_BITS/FRAGMENTS);
    localparam  ADDR_WID  = FRAG_BITS+FRAG_WID;
    localparam  PRIOWID   = IDWID;
    localparam  KWID      = DATA_BITS;
    localparam  SEGWID    = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY

	
// ==========================================================================
// == Architecture: Structural
// ==========================================================================
    wire [ DATA_BITS-1:0 ] in_key;
    wire [     IDWID-1:0 ] in_id;
    wire [   MASKWID-1:0 ] in_maskid;
    wire [   PRIOWID-1:0 ] in_priority;
    
    // Serial to Parallel Connection
    Serial_to_Parallel 	#( KWID    )  sipo_key      (CLK, RESET, KEY, in_key);
    Serial_to_Parallel 	#( IDWID   )  sipo_id       (CLK, RESET, SETTING_ID, in_id);
    Serial_to_Parallel 	#( MASKWID )  sipo_maskid   (CLK, RESET, SETTING_MASKID, in_maskid);
    Serial_to_Parallel  #( PRIOWID )  sipo_priority (CLK, RESET, SETTING_PRIORITY, in_priority);
    
    // -----------------------------------------------
    //	 TCAM CONTROLLER
    // -----------------------------------------------
   
    wire                 w_read;
    wire                 w_write;
    wire  [ADDR_WID-1:0] w_address;
    wire  [  SEGWID-1:0] w_readdata;
    wire  [  SEGWID-1:0] w_writedata;
    wire                 w_waitrequest;
    wire                 w_readdatavalid;
    
    TCAM_CONTROLLER
    #( 
        .DATA_BITS            ( DATA_BITS ), 
        .FRAGMENTS            ( FRAGMENTS ), 
        .FRAG_BITS            ( FRAG_BITS ), 
        .IDWID                ( IDWID     ),
        .MASKWID              ( MASKWID   )
    )    
    TCAM_TOP_INST   // Instance Name 
    (
        // clock and RESET 
        .CLK                  ( CLK              ),
        .RESET                ( RESET            ),
        
        // CAM's i/o
        .SEARCH               ( SEARCH           ),  // software
        .SETTING              ( SETTING          ),  // software
        .KEY                  ( in_key           ),  // software
        .SETTING_ID           ( in_id            ),  // software
        .SETTING_MASKID       ( in_maskid        ),  // software
        .SETTING_PRIORITY     ( in_priority      ),  // software
        .RULEID               ( RULEID           ),  // software  
        .SETTING_COMPLETE     ( SETTING_COMPLETE ),  // led 3
        .SEARCH_COMPLETE      ( SEARCH_COMPLETE  ),  // led 5
        .MISMATCH             ( MISMATCH         ),  // led 6
        
        // SDRAM Controller's i/o
        .SDRAM_READ           ( w_read           ),
        .SDRAM_WRITE          ( w_write          ),
        .SDRAM_ADDRESS        ( w_address        ),
        .SDRAM_READDATA       ( w_readdata       ),
        .SDRAM_WRITEDATA      ( w_writedata      ),
        .SDRAM_WAITREQUEST    ( w_waitrequest    ),
        .SDRAM_READDATAVALID  ( w_readdatavalid  )
    );
    
    // -----------------------------------------------
    //	 SDRAM CONTROLLER
    // -----------------------------------------------
    
    SDRAM_CONTROLLER  
    #(
        .ADDR_WID                   ( SDRAM_ADDR ),
        .DATA_WID                   ( SDRAM_DATA )
    )	
    SDRAM_CONTROLLER_INST 
    (
        // clock and RESET
        .CLK                        ( CLK                    ),
        .RESET                      ( RESET                  ),
        
        // avalon-mm master bi-direct (DDR3 Controller)
        .AVM_M0_WAITREQUEST         ( DDR3_AVL_WAITREQUEST   ),
        .AVM_M0_READDATA            ( DDR3_AVL_READDATA      ),
        .AVM_M0_READDATAVALID       ( DDR3_AVL_READDATAVALID ),
        .AVM_M0_READ                ( DDR3_AVL_READ          ),
        .AVM_M0_WRITE               ( DDR3_AVL_WRITE         ),
        .AVM_M0_WRITEDATA           ( DDR3_AVL_WRITEDATA     ),
        .AVM_M0_ADDRESS             ( DDR3_AVL_ADDRESS       ),	
        .AVM_M0_BURSTCOUNT          ( DDR3_AVL_BURSTCOUNT    ),
        
        // avalon-mm slave (User's Control Area)
        .AVM_S0_INIT                ( DDR3_AVL_INIT          ),  // button control 
        .AVM_S0_READ                ( w_read                 ),  // FPGA Interconnection
        .AVM_S0_WRITE               ( w_write                ),  // FPGA Interconnection
        .AVM_S0_ADDRESS             ( w_address              ),  // FPGA Interconnection
        .AVM_S0_WRITEDATA           ( w_writedata            ),  // FPGA Interconnection
        .AVM_S0_READDATA            ( w_readdata             ),  // FPGA Interconnection
        .AVM_S0_WAITREQUEST         ( w_waitrequest          ),  // FPGA Interconnection
        .AVM_S0_READDATAVALID       ( w_readdatavalid        ),  // FPGA Interconnection
        .AVM_S0_INITCOMPLETE        ( DDR3_AVL_INITCOMPLETE  )   // led control
    );
	
endmodule