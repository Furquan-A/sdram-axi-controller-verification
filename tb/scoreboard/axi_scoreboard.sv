class axi_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(axi_scoreboard)
	
	uvm_analysis_imp #(axi_transaction,axi_scoreboard) axi_imp;
	
	logic [31:0] expected_mem [bit [31:0]];
	bit [3:0] byte_valid [bit [31:0]];

	function new(string name = "axi_scoreboard", uvm_component parent = null);
		super.new(name,parent);
	endfunction 
	
	function void build_phase(uvm_phase phase);
		super.new(phase);
		
		axi_imp = new("axi_imp",this);
		
	endfunction 
	
	function void write(axi_transaction tr);
		// We'll implement transaction processing here.
		logic [31:0] beat_addr;
		int wrap_size;
		logic [31:0] wrap_boundary;
		
		if(tr.op == WRITE)
			begin
				if(tr.w_data.size() != (int'(tr.length) + 1))
					begin
						`uvm_error("AXI_SB",$sformatf("WDATA SIZE MISMATCH: Expected=%0d, Actual=%0d",int'(tr.length) + 1,tr.w_data.size()))
						return;
					end

				// Check write strobe array size
				if(tr.wstrb.size() != (int'(tr.length) + 1))
					begin
						`uvm_error("AXI_SB",$sformatf("WSTRB SIZE MISMATCH: Expected=%0d, Actual=%0d",int'(tr.length) + 1,tr.wstrb.size()))
						return;
					end
				for(int i = 0; i < tr.length+1; i++)
					begin
						case(tr.burst)
							FIXED: beat_addr = tr.addr;
							INCR : beat_addr = tr.addr + (i*4);
							WRAP: 
								begin 
									wrap_size = (int'(tr.length) + 1) * 4;
									wrap_boundary = tr.addr - (tr.addr % wrap_size);
									beat_addr = wrap_boundary + ((tr.addr - wrap_boundary + (i << 2)) % wrap_size);

								end
							default : 
								begin
									`uvm_error("AXI_SB", "Unsupported burst type")
									return;
								end
						endcase	
						update_memory(beat_addr, tr.w_data[i], tr.wstrb[i]);
					end
			end
		else if(tr.op == READ)
			begin 
				// We'll implement burst read checking next.
				if(tr.r_data.size() !== tr.length+1)
					begin 
						`uvm_error("AXI_SB",$sformatf("RDATA SIZE MISMATCH: Expected=%0d, Actual=%0d",int'(tr.length) + 1,tr.r_data.size()))
						return;
					end
				for(int i = 0; i < tr.length+1; i++)
					begin 
						case(tr.burst)
							FIXED: beat_addr = tr.addr;
							INCR : beat_addr = tr.addr + (i*4);
							WRAP: 
								begin 
									wrap_size = (int'(tr.length) + 1) * 4;
									wrap_boundary = tr.addr - (tr.addr % wrap_size);
									beat_addr = wrap_boundary + ((tr.addr - wrap_boundary + (i << 2)) % wrap_size);

								end
							default : 
								begin
									`uvm_error("AXI_SB", "Unsupported burst type")
									return;
								end
						endcase
						check_read(beat_addr,tr.r_data[i]);
					end 
			end
	endfunction
	
	function void update_memory(input logic [31:0] addr, input logic [31:0] wdata, input logic [3:0] wstrb);
	
		if(!expected_mem.exists(addr))
			begin 	
				expected_mem[addr] = 'x;
				byte_valid[addr] = '0;
			end
		for(int i=0; i<$bits(wdata)/8; i++)
			begin
				if(wstrb[i])
					begin 
						expected_mem[addr][8*i +: 8] = wdata[8*i +: 8];
						byte_valid[addr][i] = wstrb[i];
					end 
			end 
			
	endfunction
	
	function void check_read(input logic [31:0] addr, input logic [31:0] actual_rdata);

		if(!expected_mem.exists(addr))
			`uvm_warning("AXI_SB",$sformatf("Read comparison skipped: Address = %0h",addr))

		else if(byte_valid[addr] == 4'b0000)
			`uvm_warning("AXI_SB",$sformatf("No valid bytes available at address = %0h",addr))

		else
			begin
				for(int i=0; i<$bits(actual_rdata)/8; i++)
					begin
						if(byte_valid[addr][i])
							begin
								if(expected_mem[addr][8*i +: 8] !== actual_rdata[8*i +: 8])
									`uvm_error("AXI_SB",$sformatf("Mismatch: Addr=%0h, Byte=%0d, Expected=%0h, Actual=%0h",addr,i,expected_mem[addr][8*i +: 8],actual_rdata[8*i +: 8]))
							end
					end
			end

	endfunction
	
endclass 	