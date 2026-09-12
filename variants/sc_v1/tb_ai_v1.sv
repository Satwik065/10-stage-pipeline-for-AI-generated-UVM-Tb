`timescale 1ns/1ps

module tb_qpsk_loopback;
    reg clk;
    reg rst;
    reg valid_in;
    reg [1:0] bits_in;
    
    wire valid_mod_out;
    wire signed [7:0] i_out;
    wire signed [7:0] q_out;
    wire valid_demod_out;
    wire [1:0] bits_out;
    
    qpsk_modulator u_mod (
        .clk(clk), .rst(rst), .valid_in(valid_in), .bits(bits_in),
        .valid_out(valid_mod_out), .i_out(i_out), .q_out(q_out)
    );
    
    qpsk_demodulator u_demod (
        .clk(clk), .rst(rst), .valid_in(valid_mod_out),
        .i_in(i_out), .q_in(q_out),
        .valid_out(valid_demod_out), .bits(bits_out)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    integer error_count;
    integer symbol_count;
    reg [1:0] expected_queue [0:63];
    integer q_head, q_tail, q_size;
    integer wait_cycles;
    reg waiting;
    reg test_done;
    reg rst_seen_low;
    integer rst_low_count;
    
    initial begin
        #200000;
        if (!test_done) begin
            $display("[RESULT] FAIL watchdog");
            $finish;
        end
    end
    
    initial begin
        rst = 1;
        valid_in = 0;
        bits_in = 2'b00;
        error_count = 0;
        symbol_count = 0;
        q_head = 0;
        q_tail = 0;
        q_size = 0;
        wait_cycles = 0;
        waiting = 0;
        test_done = 0;
        rst_seen_low = 0;
        rst_low_count = 0;
        
        repeat (3) @(posedge clk);
        @(posedge clk);
        rst = 0;
        
        @(posedge clk);
        rst_low_count = 1;
        
        repeat (10) drive_sym(2'b00);
        repeat (10) drive_sym(2'b01);
        repeat (10) drive_sym(2'b10);
        repeat (10) drive_sym(2'b11);
        
        while (q_size > 0 || waiting) @(posedge clk);
        
        if (error_count == 0 && symbol_count == 40)
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", error_count);
        
        test_done = 1;
        $finish;
    end
    
    task drive_sym;
        input [1:0] b;
        begin
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            valid_in = 1;
            bits_in = b;
            @(posedge clk);
            valid_in = 0;
            symbol_count = symbol_count + 1;
        end
    endtask
    
    always @(posedge clk) begin
        if (rst) begin
            waiting = 0;
            wait_cycles = 0;
        end else begin
            if (^valid_in === 1'bx || ^valid_in === 1'bz ||
                ^bits_in === 1'bx || ^bits_in === 1'bz ||
                ^valid_mod_out === 1'bx || ^valid_mod_out === 1'bz ||
                ^i_out === 1'bx || ^i_out === 1'bz ||
                ^q_out === 1'bx || ^q_out === 1'bz ||
                ^valid_demod_out === 1'bx || ^valid_demod_out === 1'bz ||
                ^bits_out === 1'bx || ^bits_out === 1'bz) begin
                $display("Error: X/Z detected at %0t", $time);
                error_count = error_count + 1;
            end
            
            if (valid_in && !waiting) begin
                waiting = 1;
                wait_cycles = 0;
                expected_queue[q_tail] = bits_in;
                q_tail = (q_tail + 1) % 64;
                q_size = q_size + 1;
            end
            
            if (waiting) begin
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 6) begin
                    $display("Error: Late valid at %0t", $time);
                    error_count = error_count + 1;
                    waiting = 0;
                    q_head = (q_head + 1) % 64;
                    q_size = q_size - 1;
                end
            end
            
            if (valid_demod_out) begin
                if (!waiting || q_size == 0) begin
                    $display("Error: Duplicate valid at %0t", $time);
                    error_count = error_count + 1;
                end else begin
                    if (bits_out !== expected_queue[q_head]) begin
                        $display("Error: Mismatch at %0t, exp %b got %b", 
                                 $time, expected_queue[q_head], bits_out);
                        error_count = error_count + 1;
                    end
                    q_head = (q_head + 1) % 64;
                    q_size = q_size - 1;
                    waiting = 0;
                    wait_cycles = 0;
                end
            end
        end
    end
endmodule