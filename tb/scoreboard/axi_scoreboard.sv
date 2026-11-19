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
	
	function automatic logic [31:0] calculate_beat_addr(
		input logic [31:0] start_addr,
		input int beat,
		input burst_type_e burst,
		input int num_beats
	);

		int unsigned wrap_size;
		logic [31:0] wrap_boundary;
		logic [31:0] beat_addr;

		beat_addr = 'x;

		// Check beat index
		if(beat < 0 || beat >= num_beats)
		begin
			`uvm_error("AXI_SB", "Invalid beat index")
			return 'x;
		end

		case(burst)

			// -----------------------------------
			// FIXED BURST
			// -----------------------------------
			FIXED:
			begin
				beat_addr = start_addr;
			end

			// -----------------------------------
			// INCREMENTING BURST
			// -----------------------------------
			INCR:
			begin
				beat_addr = start_addr + (beat * 4);
			end

			// -----------------------------------
			// WRAPPING BURST
			// -----------------------------------
			WRAP:
			begin

				// Valid WRAP lengths: 2, 4, 8, 16 beats
				if(!(num_beats inside {2, 4, 8, 16}))
				begin
					`uvm_error("AXI_SB", "Invalid WRAP burst length")
					return 'x;
				end

				// Starting address must be 4-byte aligned
				if(start_addr[1:0] !== 2'b00)
				begin
					`uvm_error("AXI_SB", "Unaligned WRAP starting address")
					return 'x;
				end

				// Calculate total WRAP window size
				wrap_size = num_beats * 4;

				// Calculate lower WRAP boundary
				wrap_boundary = start_addr - (start_addr % wrap_size);

				// Calculate address of current beat
				beat_addr = wrap_boundary +
							((start_addr - wrap_boundary + (beat * 4))
							 % wrap_size);

			end

			// -----------------------------------
			// UNSUPPORTED BURST
			// -----------------------------------
			default:
			begin
				`uvm_error("AXI_SB", "Unsupported AXI burst type")
				return 'x;
			end

		endcase

		return beat_addr;

	endfunction
	
	function void write(axi_transaction tr);
		logic [31:0] beat_addr;
		int unsigned num_beats;

		if(tr == null) 
			begin
				`uvm_error("AXI_SB", "Null transaction")
				return;
			end

		if($isunknown({tr.addr, tr.length}) || tr.addr[1:0] != 0) 
			begin
				`uvm_error("AXI_SB", "Invalid address or length")
				return;
			end

		num_beats = int'(tr.length) + 1;

		case(tr.op)
			WRITE: 
				begin
					if(tr.w_data.size() != num_beats || tr.wstrb.size() != num_beats) begin
						`uvm_error("AXI_SB", "WDATA/WSTRB size mismatch")
						return;
					end
					
					if(tr.bresp !== OKAY) begin
						`uvm_error("AXI_SB", $sformatf("WRITE RESPONSE ERROR: BRESP=%0h, ADDR=%0h", tr.bresp, tr.addr))
						return;
					end
					for(int i = 0; i < num_beats; i++) 
						begin
							beat_addr = calculate_beat_addr(tr.addr, i, tr.burst, num_beats);
							if($isunknown(beat_addr)) 
								return;
							update_memory(beat_addr, tr.w_data[i], tr.wstrb[i]);
						end
				end

			READ: 
				begin
					if(tr.r_data.size() != num_beats) 
						begin
							`uvm_error("AXI_SB", "RDATA size mismatch")
							return;
						end
					if(tr.rresp.size() !== num_beats)
						begin 
							`uvm_error("AXI_SB","RRESP size mismatch")
						end 
					for(int i = 0; i < num_beats; i++) 
						begin
							beat_addr = calculate_beat_addr(tr.addr, i, tr.burst, num_beats);
							if($isunknown(beat_addr)) 
								return;
							if(tr.rresp[i] == OKAY)
								begin 
									check_read(beat_addr, tr.r_data[i]);
								end
							else 
								begin 
									`uvm_error("AXI_SB","Skip the Rdata comparison, ERROR has occured")	
									continue;
								end 
						end	
				end

			default: `uvm_error("AXI_SB", "Unsupported operation")
		endcase
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