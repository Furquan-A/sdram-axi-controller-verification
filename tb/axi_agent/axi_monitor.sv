class axi_monitor extends uvm_monitor;

    `uvm_component_utils(axi_monitor)

    virtual axi_if.MONITOR vif;

    // Publishes completed AXI transactions
    uvm_analysis_port #(axi_transaction) ap;


    function new(string name = "axi_monitor",
                 uvm_component parent = null);

        super.new(name, parent);
        ap = new("ap", this);

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual axi_if.MONITOR)::get(
                this, "", "vif", vif)) begin

            `uvm_fatal(
                "AXI_MON",
                "Cannot get axi_if from config_db. Was it set?"
            )

        end

    endfunction


    task run_phase(uvm_phase phase);

        // Read and write activity can happen independently,
        // so monitor both concurrently.
        fork

            begin
                forever begin
                    monitor_write_transaction();
                end
            end

            begin
                forever begin
                    monitor_read_transaction();
                end
            end

        join

    endtask


    // =========================================================
    // WRITE MONITOR
    // =========================================================
    task monitor_write_transaction();

        axi_transaction tr;
        int unsigned beats;

        tr = axi_transaction::type_id::create("write_tr");

        tr.op = axi_transaction::WRITE;


        // =====================================================
        // AW CHANNEL
        // =====================================================
        forever begin

            @(vif.mon_cb);

            if (vif.mon_cb.AWVALID &&
                vif.mon_cb.AWREADY) begin

                tr.addr   = vif.mon_cb.AWADDR;
                tr.id     = vif.mon_cb.AWID;
                tr.length = vif.mon_cb.AWLEN;

                tr.burst =
                    axi_transaction::burst_type_e'(
                        vif.mon_cb.AWBURST
                    );

                break;

            end

        end


        // =====================================================
        // Allocate Write Beat Storage
        // =====================================================
        tr.w_data = new[tr.length + 1];
        tr.wstrb  = new[tr.length + 1];

        beats = 0;


        // =====================================================
        // W CHANNEL
        // =====================================================
        while (beats < (tr.length + 1)) begin

            @(vif.mon_cb);

            if (vif.mon_cb.WVALID &&
                vif.mon_cb.WREADY) begin

                tr.w_data[beats] = vif.mon_cb.WDATA;
                tr.wstrb[beats]  = vif.mon_cb.WSTRB;


                // WLAST asserted too early
                if ((beats < tr.length) &&
                    vif.mon_cb.WLAST) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "WLAST asserted early. Beat=%0d Expected last beat=%0d",
                            beats,
                            tr.length
                        )
                    )

                end


                // WLAST missing on final beat
                if ((beats == tr.length) &&
                    !vif.mon_cb.WLAST) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "WLAST missing on final beat. Beat=%0d",
                            beats
                        )
                    )

                end


                beats++;

            end

        end


        // =====================================================
        // B CHANNEL
        // =====================================================
        forever begin

            @(vif.mon_cb);

            if (vif.mon_cb.BVALID &&
                vif.mon_cb.BREADY) begin


                // Response ID should match request ID
                if (vif.mon_cb.BID != tr.id) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "BID mismatch. AWID=%0d BID=%0d",
                            tr.id,
                            vif.mon_cb.BID
                        )
                    )

                end


                tr.bresp =
                    axi_transaction::resp_type_e'(
                        vif.mon_cb.BRESP
                    );

                break;

            end

        end


        // =====================================================
        // Complete Write Transaction
        // =====================================================
        `uvm_info(
            "AXI_MON",
            $sformatf(
                "Observed WRITE: ADDR=0x%08h ID=%0d LEN=%0d BURST=%s BRESP=%s",
                tr.addr,
                tr.id,
                tr.length,
                tr.burst.name(),
                tr.bresp.name()
            ),
            UVM_MEDIUM
        )


        // Publish completed write transaction
        ap.write(tr);

    endtask



    // =========================================================
    // READ MONITOR
    // =========================================================
    task monitor_read_transaction();

        axi_transaction tr;
        int unsigned beats;

        tr = axi_transaction::type_id::create("read_tr");

        tr.op = axi_transaction::READ;


        // =====================================================
        // AR CHANNEL
        // =====================================================
        forever begin

            @(vif.mon_cb);

            if (vif.mon_cb.ARVALID &&
                vif.mon_cb.ARREADY) begin

                tr.addr   = vif.mon_cb.ARADDR;
                tr.id     = vif.mon_cb.ARID;
                tr.length = vif.mon_cb.ARLEN;

                tr.burst =
                    axi_transaction::burst_type_e'(
                        vif.mon_cb.ARBURST
                    );

                break;

            end

        end


        // =====================================================
        // Allocate Read Beat Storage
        // =====================================================
        tr.r_data = new[tr.length + 1];
        tr.rresp  = new[tr.length + 1];

        beats = 0;


        // =====================================================
        // R CHANNEL
        // =====================================================
        while (beats < (tr.length + 1)) begin

            @(vif.mon_cb);

            if (vif.mon_cb.RVALID &&
                vif.mon_cb.RREADY) begin


                // Capture this accepted read beat
                tr.r_data[beats] = vif.mon_cb.RDATA;

                tr.rresp[beats] =
                    axi_transaction::resp_type_e'(
                        vif.mon_cb.RRESP
                    );


                // RID should match ARID
                if (vif.mon_cb.RID != tr.id) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "RID mismatch. Expected RID=%0d Received RID=%0d",
                            tr.id,
                            vif.mon_cb.RID
                        )
                    )

                end


                // RLAST asserted too early
                if ((beats < tr.length) &&
                    vif.mon_cb.RLAST) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "RLAST asserted early. Beat=%0d Expected last beat=%0d",
                            beats,
                            tr.length
                        )
                    )

                end


                // RLAST missing on final beat
                if ((beats == tr.length) &&
                    !vif.mon_cb.RLAST) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "RLAST missing on final beat. Beat=%0d",
                            beats
                        )
                    )

                end


                // One accepted R handshake = one beat
                beats++;

            end

        end


        // =====================================================
        // Complete Read Transaction
        // =====================================================
        `uvm_info(
            "AXI_MON",
            $sformatf(
                "Observed READ: ADDR=0x%08h ID=%0d LEN=%0d BURST=%s BEATS=%0d",
                tr.addr,
                tr.id,
                tr.length,
                tr.burst.name(),
                tr.length + 1
            ),
            UVM_MEDIUM
        )


        // Optionally print each returned beat
        foreach (tr.r_data[i]) begin

            `uvm_info(
                "AXI_MON",
                $sformatf(
                    "READ Beat[%0d]: RDATA=0x%08h RRESP=%s",
                    i,
                    tr.r_data[i],
                    tr.rresp[i].name()
                ),
                UVM_MEDIUM
            )

        end


        // Publish completed read transaction
        ap.write(tr);

    endtask


endclass