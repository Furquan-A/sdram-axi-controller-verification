interface sdram_if #(
    parameter int SDRAM_ADDR_WIDTH = 13,
    parameter int SDRAM_DATA_WIDTH = 16,
    parameter int SDRAM_BANK_WIDTH = 2
);

    // ---------- SDRAM Address ----------
    logic [SDRAM_ADDR_WIDTH-1:0] sdram_addr;  // Multiplexed row/column address
    logic [SDRAM_BANK_WIDTH-1:0] sdram_ba;    // Bank address

    // ---------- Clock / Control --------
    logic sdram_clk;
    logic sdram_cke;

    // ---------- Command Signals --------
    logic sdram_cs;
    logic sdram_ras;
    logic sdram_cas;
    logic sdram_we;

    // ---------- Data Mask --------------
    logic [(SDRAM_DATA_WIDTH/8)-1:0] sdram_dqm;

    // ---------- Data Path --------------
    logic [SDRAM_DATA_WIDTH-1:0] sdram_data_output;
    logic                        sdram_data_out_en;
    logic [SDRAM_DATA_WIDTH-1:0] sdram_data_input;

	clocking mon_cb @(posedge sdram_clk);
		default input #1step output #0;
		
		input sdram_addr,sdram_ba;
		input sdram_cke;
		input sdram_cs,sdram_ras,sdram_cas,sdram_we;
		input sdram_dqm;
		input sdram_data_output,sdram_data_out_en,sdram_data_input;
		
	endclocking 
	
	clocking rsp_cb @(posedge sdram_clk);
		default input #1step output#0;
		
		// SDRAM responder model:
	// - Acts like the external SDRAM device.
	// - DUT/controller acts as the SDRAM command master.
	// - Responder samples command/address/control signals from DUT.
	// - On WRITE, responder stores DUT-provided 16-bit data transfers.
	// - On READ, responder drives 16-bit data back to the DUT.
	// - For this controller, one 32-bit AXI beat is handled as two
	//   16-bit SDRAM data transfers; the controller combines them.
	
		input sdram_addr,sdram_ba,sdram_cas,sdram_ras;
		input sdram_we,sdram_cs,sdram_dqm;
		input sdram_data_output,sdram_data_out_en,sdram_cke;
		
		output sdram_data_input;
	
	endclocking
	
	modport MONITOR( 
		clocking mon_cb
	);
	
	modport RESPONDER(
		clocking rsp_cb
	);

	modport DUT (
		// Clock / control
		output sdram_clk,
		output sdram_cke,

		// Commands
		output sdram_cs,
		output sdram_ras,
		output sdram_cas,
		output sdram_we,

		// Address
		output sdram_addr,
		output sdram_ba,

		// Data mask
		output sdram_dqm,

		// DUT -> SDRAM write data
		output sdram_data_output,
		output sdram_data_out_en,

		// SDRAM -> DUT read data
		input  sdram_data_input
	);
		
endinterface 