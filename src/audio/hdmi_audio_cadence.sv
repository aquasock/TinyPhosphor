// SPDX-License-Identifier: GPL-3.0-only
// Count the audio frames handed to the HDMI packetizer over one second of
// the pixel clock: the low half counts every clk_audio pulse, the high half
// those that carried a decoded sample.  Both clocks come from the 50 MHz
// crystal, so a 48 kHz stream reads 48000 in each half while it plays.
module hdmi_audio_cadence #(
    parameter integer WINDOW_CYCLES = 74_250_000 // 1 s at 74.25 MHz
) (
    input  logic        clk_pixel,
    input  logic        resetn,
    input  logic        clk_audio,
    input  logic        sample_present,
    output logic [31:0] cadence
);
    logic [$clog2(WINDOW_CYCLES)-1:0] window_count;
    logic [15:0] frames, present;

    always_ff @(posedge clk_pixel) begin
        if (!resetn) begin
            window_count <= 0;
            frames <= 0;
            present <= 0;
            cadence <= 0;
        end else if (window_count == WINDOW_CYCLES - 1) begin
            window_count <= 0;
            cadence <= {present + 16'(clk_audio && sample_present),
                        frames + 16'(clk_audio)};
            frames <= 0;
            present <= 0;
        end else begin
            window_count <= window_count + 1'b1;
            if (clk_audio) begin
                frames <= frames + 1'b1;
                if (sample_present) present <= present + 1'b1;
            end
        end
    end
endmodule
