//////////////////////////////////////////////////////////
//	Category	  : Logic Design						//
//	Name File     : sdram_controller.v                  //
//	Author        : Dang Tieu Binh                      //
//	Email         : dangtieubinh0207@gmail.com          //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		//
//	Start design  : 05.02.2022                          //
//	Last revision : 06.10.2022                          //
//////////////////////////////////////////////////////////


module SDRAM_CONTROLLER (
        // clock and RESET
        input 		                CLK
       ,input 		                RESET
        
        // avalon-mm master bi-direct
       ,input                       AVM_M0_WAITREQUEST
       ,input       [DATA_WID-1:0]	AVM_M0_READDATA
       ,input                       AVM_M0_READDATAVALID
       ,output                      AVM_M0_READ
       ,output                      AVM_M0_WRITE
       ,output reg  [DATA_WID-1:0]	AVM_M0_WRITEDATA
       ,output reg  [ADDR_WID-1:0]	AVM_M0_ADDRESS
       ,output      [        10:0]  AVM_M0_BURSTCOUNT
        
        // avalon-mm slave
       ,input                       AVM_S0_INIT
       ,input                       AVM_S0_READ
       ,input                       AVM_S0_WRITE
       ,input       [ADDR_WID-1:0]  AVM_S0_ADDRESS
       ,input       [DATA_WID-1:0]  AVM_S0_WRITEDATA
       ,output reg  [DATA_WID-1:0]  AVM_S0_READDATA
       ,output                      AVM_S0_INITCOMPLETE
       ,output                      AVM_S0_WAITREQUEST
       ,output                      AVM_S0_READDATAVALID
	);

// ===================================================
//	 Definitions
// ===================================================	
    `define  ADDR			29'h1fff_ffff	// Maximum
    `define  BURST_LENGTH	1

// ===================================================
//	 Parameters
// ===================================================
    parameter ADDR_WID = 27;
    parameter DATA_WID = 32;

// ===================================================
//	 Local Parameters
// ===================================================
    localparam IDLE  = 2'd0;
    localparam INIT  = 2'd1;
    localparam READ  = 2'd2;
    localparam WRITE = 2'd3;

// ===================================================
//	 Input Registered
// ===================================================
    // Avalon-mm Slave
    reg [ADDR_WID-1:0] 	avs_address_sync1;
    reg [DATA_WID-1:0] 	avs_writedata_sync1;
    reg 				avs_init_sync1;
    reg 				avs_read_sync1;
    reg 				avs_write_sync1;
    
    always @(posedge CLK or posedge RESET)
    begin 
        if (RESET) begin 
            avs_init_sync1  	<= 0;
            avs_read_sync1  	<= 0;
            avs_write_sync1 	<= 0;
            avs_address_sync1 	<= 0;
            avs_writedata_sync1 <= 0;
        end 
        else begin 
            avs_init_sync1  	<= AVM_S0_INIT;
            avs_read_sync1  	<= AVM_S0_READ;
            avs_write_sync1 	<= AVM_S0_WRITE;
            avs_address_sync1 	<= AVM_S0_ADDRESS;
            avs_writedata_sync1 <= AVM_S0_WRITEDATA;
        end
    end
    
// ===================================================
//	 Logic Declarations
// ===================================================	
    // Init RESET
    wire [ADDR_WID-1:0] max_address;
    assign max_address = {ADDR_WID{1'b1}};
    
    wire max_avm_address;
    assign max_avm_address = (AVM_M0_ADDRESS == max_address) ? 1'b1 : 1'b0;
    
    // burst count 
    reg [3:0] wr_burst_count;
    
    // complete signal
    reg drv_status_waitrequest;
    reg drv_status_init_complete;
    reg drv_status_readdatavalid;
    
    // -- Finite State Machine
    reg [1:0] current_state;
    //reg [1:0] next_state;
    
    always @(posedge CLK or posedge RESET) 	// Async RESET
    begin 
        if (RESET) begin
            current_state <= IDLE;
            drv_status_init_complete <= 0;
        end
        
        // out of RESET
        else begin
            case (current_state)
                // IDLE 
                IDLE : begin
                    drv_status_waitrequest   <= 1'b0;
                    drv_status_readdatavalid <= 1'b1;
                    
                    // Init Enable
                    if (avs_init_sync1 == 1) begin
                        AVM_M0_ADDRESS   <= 0;
                        AVM_M0_WRITEDATA <= 0;
                        wr_burst_count 	 <= 0;
                        current_state 	 <= INIT;	// Go to INIT
                        drv_status_init_complete <= 0;
                    end
                    // Read Enable
                    else if (avs_read_sync1 == 1) begin 
                        AVM_M0_ADDRESS <= avs_address_sync1;
                        drv_status_readdatavalid <= 1'b0;
                        current_state  <= READ;	// Go to READ
                    end 
                    
                    // Write Enable
                    else if (avs_write_sync1 == 1) begin
                        AVM_M0_ADDRESS   <= avs_address_sync1;
                        AVM_M0_WRITEDATA <= avs_writedata_sync1;
                        current_state    <= WRITE; // Go to WRITE
                    end
                    
                    // Catch-all
                    else begin
                        AVM_M0_ADDRESS   <= AVM_M0_ADDRESS;
                        AVM_M0_WRITEDATA <= AVM_M0_WRITEDATA;
                        current_state <= IDLE; 	// Wait here IDLE
                    end
                end
                
                // INIT STATE
                INIT : begin
                    drv_status_waitrequest <= 1'b1;
                    
                    // Not at Max address
                    if (!AVM_M0_WAITREQUEST & !max_avm_address) begin 
                        if (wr_burst_count == 0) begin 
                            AVM_M0_ADDRESS <= AVM_M0_ADDRESS + 1;
                            wr_burst_count <= 0;
                        end
                        else begin 
                            wr_burst_count <= wr_burst_count + 1;
                        end
                    end
    
                    // Max address 
                    else if (!AVM_M0_WAITREQUEST & max_avm_address) begin 
                        if (wr_burst_count == 0) begin 
                            drv_status_init_complete <= 1;
                            current_state <= IDLE;	// Go back to IDLE (complete)
                        end
                        else begin 
                            wr_burst_count <= wr_burst_count + 1;
                        end
                    end
                    
                    // Catch-all
                    else begin 
                        wr_burst_count <= wr_burst_count + 1;
                    end 
                end
                
                // READ STATE
                READ : begin
                    drv_status_waitrequest <= 1'b1;
                    
                    if (!AVM_M0_WAITREQUEST & !AVM_M0_READDATAVALID) begin
                        current_state <= READ;	// Wait here
                    end
                    else if (!AVM_M0_WAITREQUEST & AVM_M0_READDATAVALID) begin
                        drv_status_readdatavalid <= 1'b1;
                        current_state <= IDLE; 
                    end
                    else begin
                        current_state <= READ; // Wait here
                    end
                end
                
                // WRITE STATE
                WRITE : begin
                    drv_status_waitrequest <= 1'b1;
                    
                    if (!AVM_M0_WAITREQUEST)	current_state <= IDLE;
                    else 						current_state <= WRITE; // Wait here
                end 
                
                // catch-all
                default : begin 
                    current_state <= current_state;
                end 
            endcase
        end
    end 
    
    // Avalon-mm Master Output Assignment (to DDR3)
    assign AVM_M0_BURSTCOUNT = `BURST_LENGTH;
    assign AVM_M0_WRITE = ((current_state==WRITE || current_state==INIT) && RESET==0) ? 1'b1 : 1'b0;
    assign AVM_M0_READ  = (current_state==READ && RESET==0) ? 1'b1 : 1'b0;
    
    // Avalon-mm Slave Output Assignment (from DDR3 to FPGA)
    assign AVM_S0_WAITREQUEST   = drv_status_waitrequest;
    assign AVM_S0_INITCOMPLETE  = drv_status_init_complete;
    assign AVM_S0_READDATAVALID = drv_status_readdatavalid;
    
    // Registered Output
    always @(posedge CLK or posedge RESET) 
    begin 
        // Reset
        if 		(RESET)					AVM_S0_READDATA <= 0;
        else if (AVM_M0_READDATAVALID)	AVM_S0_READDATA <= AVM_M0_READDATA;
        else 							AVM_S0_READDATA <= AVM_S0_READDATA;
    end 
endmodule
