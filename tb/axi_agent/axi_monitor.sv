class axi_monitor extends uvm_monitor;
	`uvm_component_utils(axi_monitor)
	
	parameter int AXI_ADDR_WIDTH = 32;
    parameter int AXI_DATA_WIDTH = 32;
    parameter int ID_WIDTH       = 4;
    parameter int LEN_WIDTH      = 8;
	
	virtual axi_if.MONITOR vif;
	
	uvm_analysis_fifo#(axi_transaction) ap;
	
	function new(string name = "axi_monitor", uvm_component parent);
		super.new(name,parent);
		ap = new("ap");
	endfunction 
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		if(!uvm_config_db)#(virtual axi_if.MONITOR)::get(this,"","vif",vif))
			`uvm_fatal("AXI_MON","Cannot get the axi_if from the config db. did you set it already ?")
	endfunction
	
	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		
		fork
			monitor_write_transaction();
			monitor_read_transaction();
		join
		
	endtask 
	
	task monitor_write_transaction();
		logic [AXI_DATA_WIDTH-1:0] wdata[];
		logic [AXI_ADDR_WIDTH-1:0]waddr;
		logic [ID_WIDTH-1:0] wid;
		logic [LEN_WIDTH-1:0] wlen;
		logic [1:0] burst;
		logic [7:0] beats;
		logic [(AXI_DATA_WIDTH/8)-1:0] wstrb[];
		bit wlast;
		int i;
		
		forever 
			begin 
				@(vif.mon_cb)
				if(vif.mon_cb.AWVALID && vif.mon_cb.AWREADY)
					begin
						waddr = vif.mon_cb.AWADDR;
						wid  = vif.mon_cb.AWID;
						wlen = vif.mon_cb.AWLEN;
						burst = vif.mon_cb.AWBURST; // Burst Type 
						break;
					end
			end 
			
		wdata= new[wlen+1];
		wstrb= new[wlen+1];
		beats = 0;
		while(beats<wlen+1)
		begin
			@(vif.mon_cb);
			if(vif.mon_cb.WVALID && vif.mon_cb.WREADY)
				begin 
					wdata[beats] = vif.mon_cb.WDATA;
					wstrb[beats] = vif.mon_cb.WSTRB;
					if ((beats < wlen) && vif.mon_cb.WLAST) 
						begin
						`uvm_error("AXI_MON",$sformatf("WLAST asserted early. Beat=%0d Expected last beat=%0d",beats, wlen))
					end

					// WLAST missing on final beat
					if ((beats == wlen) && !vif.mon_cb.WLAST) 
						begin
						`uvm_error("AXI_MON",$sformatf("WLAST missing on final beat. Beat=%0d",beats))
					end

					// One accepted W handshake = one completed beat
					beats++;
				end
		end
	endtask
endclass 