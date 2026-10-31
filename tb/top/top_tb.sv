import uvm_pkg::*;
`include "uvm_macros.svh"

module tb_top;

	logic clk;
	logic rst;


	// ---------------------------------------------------------
	// INTERFACES
	// ---------------------------------------------------------

	axi_if axi_vif(clk,rst_i);
	sdram_if sdram_vif(clk);


	// ---------------------------------------------------------
	// CLOCK
	// ---------------------------------------------------------

	initial
		begin
			clk = 0;
			forever #5 clk = ~clk;
		end


	// ---------------------------------------------------------
	// RESET
	// ---------------------------------------------------------

	initial
		begin
			rst = 1;
			repeat(5) @(posedge clk);
			rst = 0;
		end


	// ---------------------------------------------------------
	// DUT
	// ---------------------------------------------------------

	sdram_axi dut
	(
		// CLOCK / RESET
		.clk_i(clk),
		.rst_i(rst),

		// AXI WRITE ADDRESS
		.inport_awvalid_i(axi_vif.AWVALID),
		.inport_awaddr_i(axi_vif.AWADDR),
		.inport_awid_i(axi_vif.AWID),
		.inport_awlen_i(axi_vif.AWLEN),
		.inport_awburst_i(axi_vif.AWBURST),
		.inport_awready_o(axi_vif.AWREADY),

		// AXI WRITE DATA
		.inport_wvalid_i(axi_vif.WVALID),
		.inport_wdata_i(axi_vif.WDATA),
		.inport_wstrb_i(axi_vif.WSTRB),
		.inport_wlast_i(axi_vif.WLAST),
		.inport_wready_o(axi_vif.WREADY),

		// AXI WRITE RESPONSE
		.inport_bready_i(axi_vif.BREADY),
		.inport_bvalid_o(axi_vif.BVALID),
		.inport_bresp_o(axi_vif.BRESP),
		.inport_bid_o(axi_vif.BID),

		// AXI READ ADDRESS
		.inport_arvalid_i(axi_vif.ARVALID),
		.inport_araddr_i(axi_vif.ARADDR),
		.inport_arid_i(axi_vif.ARID),
		.inport_arlen_i(axi_vif.ARLEN),
		.inport_arburst_i(axi_vif.ARBURST),
		.inport_arready_o(axi_vif.ARREADY),

		// AXI READ DATA
		.inport_rready_i(axi_vif.RREADY),
		.inport_rvalid_o(axi_vif.RVALID),
		.inport_rdata_o(axi_vif.RDATA),
		.inport_rresp_o(axi_vif.RRESP),
		.inport_rid_o(axi_vif.RID),
		.inport_rlast_o(axi_vif.RLAST),

		// SDRAM
		.sdram_clk_o(sdram_vif.sdram_clk),
		.sdram_cke_o(sdram_vif.sdram_cke),
		.sdram_cs_o(sdram_vif.sdram_cs),
		.sdram_ras_o(sdram_vif.sdram_ras),
		.sdram_cas_o(sdram_vif.sdram_cas),
		.sdram_we_o(sdram_vif.sdram_we),
		.sdram_dqm_o(sdram_vif.sdram_dqm),
		.sdram_addr_o(sdram_vif.sdram_addr),
		.sdram_ba_o(sdram_vif.sdram_ba),
		.sdram_data_input_i(sdram_vif.sdram_data_input),
		.sdram_data_output_o(sdram_vif.sdram_data_output),
		.sdram_data_out_en_o(sdram_vif.sdram_data_out_en)
	);


	// ---------------------------------------------------------
	// UVM CONFIGURATION
	// ---------------------------------------------------------

	initial
		begin

			uvm_config_db#(virtual axi_if.DRIVER)::set(null,"uvm_test_top*","vif",axi_vif);
			uvm_config_db#(virtual axi_if.MONITOR)::set(null,"uvm_test_top*","vif",axi_vif);

			uvm_config_db#(virtual sdram_if.MONITOR)::set(null,"uvm_test_top*","vif",sdram_vif);
			uvm_config_db#(virtual sdram_if.RESPONDER)::set(null,"uvm_test_top*","rsp_if",sdram_vif);

			run_test();

		end

endmodule