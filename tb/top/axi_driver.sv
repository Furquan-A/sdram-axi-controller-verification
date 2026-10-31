import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_driver extends uvm_driver #(axi_transaction);

	`uvm_component_utils(axi_driver)

	virtual axi_if.DRIVER vif;


	// ---------------------------------------------------------
	// CONSTRUCTOR
	// ---------------------------------------------------------

	function new(string name = "axi_driver", uvm_component parent = null);
		super.new(name,parent);
	endfunction


	// ---------------------------------------------------------
	// BUILD PHASE
	// ---------------------------------------------------------

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db#(virtual axi_if.DRIVER)::get(this,"","vif",vif))
			`uvm_fatal("AXI_DRV","Cannot get axi_if from config_db. Did you set it in tb_top?")

	endfunction


	// ---------------------------------------------------------
	// INITIALIZE AXI MASTER SIGNALS
	// ---------------------------------------------------------

	task initialize_signals();

		// AXI Write Address Channel
		vif.drv_cb.AWVALID <= '0;
		vif.drv_cb.AWADDR <= '0;
		vif.drv_cb.AWID <= '0;
		vif.drv_cb.AWLEN <= '0;
		vif.drv_cb.AWBURST <= '0;

		// AXI Write Data Channel
		vif.drv_cb.WVALID <= '0;
		vif.drv_cb.WDATA <= '0;
		vif.drv_cb.WSTRB <= '0;
		vif.drv_cb.WLAST <= '0;

		// AXI Write Response Channel
		vif.drv_cb.BREADY <= '0;

		// AXI Read Address Channel
		vif.drv_cb.ARVALID <= '0;
		vif.drv_cb.ARADDR <= '0;
		vif.drv_cb.ARID <= '0;
		vif.drv_cb.ARLEN <= '0;
		vif.drv_cb.ARBURST <= '0;

		// AXI Read Data Channel
		vif.drv_cb.RREADY <= '0;

	endtask


	// ---------------------------------------------------------
	// WAIT FOR RESET RELEASE
	// ---------------------------------------------------------

	task wait_for_reset();

		while(vif.rst)
			begin
				initialize_signals();
				@(vif.drv_cb);
			end

	endtask


	// ---------------------------------------------------------
	// COMPLETE WRITE TRANSACTION
	// ---------------------------------------------------------

	task drive_write(axi_transaction tr);

		drive_aw(tr);
		drive_w(tr);
		receive_b(tr);

	endtask


	// ---------------------------------------------------------
	// WRITE ADDRESS CHANNEL
	// ---------------------------------------------------------

	task drive_aw(axi_transaction tr);

		vif.drv_cb.AWADDR <= tr.addr;
		vif.drv_cb.AWID <= tr.id;
		vif.drv_cb.AWLEN <= tr.length;
		vif.drv_cb.AWBURST <= tr.burst;
		vif.drv_cb.AWVALID <= 1'b1;

		do
			begin
				@(vif.drv_cb);
			end
		while(!vif.drv_cb.AWREADY);

		vif.drv_cb.AWVALID <= 1'b0;

	endtask


	// ---------------------------------------------------------
	// WRITE DATA CHANNEL
	// ---------------------------------------------------------

	task drive_w(axi_transaction tr);

		int beat;

		for(beat = 0; beat <= tr.length; beat++)
			begin

				vif.drv_cb.WDATA <= tr.w_data[beat];
				vif.drv_cb.WSTRB <= tr.wstrb[beat];
				vif.drv_cb.WLAST <= (beat == tr.length);
				vif.drv_cb.WVALID <= 1'b1;

				do
					begin
						@(vif.drv_cb);
					end
				while(!vif.drv_cb.WREADY);

			end

		vif.drv_cb.WVALID <= 1'b0;
		vif.drv_cb.WLAST <= 1'b0;

	endtask


	// ---------------------------------------------------------
	// WRITE RESPONSE CHANNEL
	// ---------------------------------------------------------

	task receive_b(axi_transaction tr);

		vif.drv_cb.BREADY <= 1'b1;

		do
			begin
				@(vif.drv_cb);
			end
		while(!vif.drv_cb.BVALID);

		tr.bresp = resp_type_e'(vif.drv_cb.BRESP);

		if(vif.drv_cb.BID != tr.id)
			`uvm_error("AXI_DRV",$sformatf("BID mismatch: Expected ID=%0d, Received BID=%0d",tr.id,vif.drv_cb.BID))

		vif.drv_cb.BREADY <= 1'b0;

	endtask


	// ---------------------------------------------------------
	// COMPLETE READ TRANSACTION
	// ---------------------------------------------------------

	task drive_read(axi_transaction tr);

		drive_ar(tr);
		receive_r(tr);

	endtask


	// ---------------------------------------------------------
	// READ ADDRESS CHANNEL
	// ---------------------------------------------------------

	task drive_ar(axi_transaction tr);

		vif.drv_cb.ARADDR <= tr.addr;
		vif.drv_cb.ARID <= tr.id;
		vif.drv_cb.ARLEN <= tr.length;
		vif.drv_cb.ARBURST <= tr.burst;
		vif.drv_cb.ARVALID <= 1'b1;

		do
			begin
				@(vif.drv_cb);
			end
		while(!vif.drv_cb.ARREADY);

		vif.drv_cb.ARVALID <= 1'b0;

	endtask


	// ---------------------------------------------------------
	// READ DATA CHANNEL
	// ---------------------------------------------------------

	task receive_r(axi_transaction tr);

		int beat;

		tr.r_data = new[tr.length + 1];
		tr.rresp = new[tr.length + 1];

		vif.drv_cb.RREADY <= 1'b1;

		for(beat = 0; beat <= tr.length; beat++)
			begin

				do
					begin
						@(vif.drv_cb);
					end
				while(!vif.drv_cb.RVALID);

				tr.r_data[beat] = vif.drv_cb.RDATA;
				tr.rresp[beat] = resp_type_e'(vif.drv_cb.RRESP);

				if(vif.drv_cb.RID != tr.id)
					`uvm_error("AXI_DRV",$sformatf("RID mismatch: Expected ID=%0d, Received RID=%0d",tr.id,vif.drv_cb.RID))

				if((beat == tr.length) && !vif.drv_cb.RLAST)
					`uvm_error("AXI_DRV","RLAST not asserted on final read beat")

				if((beat != tr.length) && vif.drv_cb.RLAST)
					`uvm_error("AXI_DRV",$sformatf("RLAST asserted early on beat %0d",beat))

			end

		vif.drv_cb.RREADY <= 1'b0;

	endtask


	// ---------------------------------------------------------
	// RUN PHASE
	// ---------------------------------------------------------

	task run_phase(uvm_phase phase);

		initialize_signals();
		wait_for_reset();

		forever
			begin

				seq_item_port.get_next_item(req);

				if(req.op == WRITE)
					drive_write(req);
				else if(req.op == READ)
					drive_read(req);
				else
					`uvm_error("AXI_DRV","Unknown AXI transaction operation")

				seq_item_port.item_done();

			end

	endtask


endclass