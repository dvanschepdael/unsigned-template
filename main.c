/*
 * Minimal game entry points for Neo Geo AES/MVS.
 * Add game state and callbacks here; Unsigned owns the frame loop and BIOS
 * session transitions, while ngdevkit provides the interrupt handlers.
 */
#include "display/ui/blink.h"
#include "input/input.h"
#include "system/neogeo/runtime.h"
#include "system/neogeo/video.h"

#include <ngdevkit/bios-calls.h>
#include <ngdevkit/neogeo.h>
#include <ngdevkit/ng-fix.h>

/* Keep mutable game state together: every runtime callback receives this context. */
typedef struct Game {
    UInputManager input;
    UUIBlink prompt_blink;
    UNeoGeoPhase phase;
} Game;

/* Set up each screen once on entry; use the frame callbacks for changing content. */
static void game_enter_phase(void *context, UNeoGeoPhase phase) {
    Game *game = context;
    game->phase = phase;
    /* Start each screen with a visible prompt and no text left from the previous one. */
    unsigned_ui_blink_reset(&game->prompt_blink, true);
    bios_fix_clear();
    ng_center_text(10, 0, "UNSIGNED TEMPLATE");

    if (phase == U_NEO_GEO_PHASE_GAME) {
        ng_center_text(14, 0, "YOUR GAME STARTS HERE");
        ng_center_text(17, 0, "A: GAME OVER");
    } else if (phase == U_NEO_GEO_PHASE_GAME_OVER) {
        ng_center_text(14, 0, "GAME OVER");
        ng_center_text(17, 0, "A: RETURN TO TITLE");
    }
}

/*
 * Called once per frame, after input polling and before rendering.
 * Add gameplay updates here, guarded by U_NEO_GEO_PHASE_GAME when appropriate.
 * The runtime already polls controllers and waits for VBlank: do not repeat either.
 */
static void game_tick(void *context) {
    Game *game = context;
    if (game->phase == U_NEO_GEO_PHASE_ATTRACT || game->phase == U_NEO_GEO_PHASE_TITLE) {
        unsigned_ui_blink_tick(&game->prompt_blink);
    }
    /* Use the press edge so holding A cannot also dismiss the game-over screen. */
    if ((game->input.players[0].state.pressed & U_INPUT_BUTTON_A) != 0u) {
        if (game->phase == U_NEO_GEO_PHASE_GAME) {
            /* Replace this demo shortcut with your game's defeat/completion condition.
             * Deactivating the players lets the runtime enter GAME_OVER. */
            unsigned_neo_geo_request_game_over();
        } else if (game->phase == U_NEO_GEO_PHASE_GAME_OVER) {
            /* Finish the session only when its final screen is ready to close. */
            unsigned_neo_geo_end_session();
        }
    }
}

/* Draw phase-specific UI after the optional main scene rendering callback. */
static void game_render_phase(void *context, UNeoGeoPhase phase) {
    Game *game = context;
    if (phase == U_NEO_GEO_PHASE_ATTRACT || phase == U_NEO_GEO_PHASE_TITLE) {
        /* Let the platform choose the prompt from AES/MVS mode and BIOS credits. */
        const char *prompt = unsigned_neo_geo_attract_prompt() == U_NEO_GEO_PROMPT_INSERT_COIN ? "INSERT COIN" : "PRESS START";
        /* FIX tiles persist until overwritten. Eleven spaces clear either prompt
         * at the same centered position during the hidden half of the blink. */
        ng_center_text(16, 0, unsigned_ui_blink_is_visible(&game->prompt_blink) ? prompt : "           ");
    }
}

/* The runtime prepares platform services before calling this for USER 2/3.
 * START requests stay disabled until initialization succeeds. */
static bool game_initialize(void *context) {
    Game *game = context;
    /* Video detection is already complete: toggle every half second at 50/60 Hz. */
    unsigned_ui_blink_init(&game->prompt_blink, unsigned_video_get_refresh_rate() / 2u, true);
    /* Prepare both local controllers before the runtime performs its first poll. */
    if (!unsigned_input_manager_init(&game->input, 2u)) {
        return false;
    }
    /* Palette 0 matches font.fix: transparent background, text and shadow.
     * Configure additional palettes here when introducing your own graphics. */
    MMAP_PALBANK1[0] = 0x8000;
    MMAP_PALBANK1[1] = 0x0fff;
    MMAP_PALBANK1[2] = 0x0555;
    return true;
}

static int game_run(bool mvs_title) {
    /* These stack objects remain alive throughout the blocking runtime call. */
    Game game = { 0 };
    /* Add .start_game to initialize a new session and .render to draw your scene.
     * Omitted callbacks are NULL and are skipped by the runtime. */
    const UNeoGeoRuntimeDefinition runtime = {
        .context = &game,
        .input = &game.input,
        .initialize = game_initialize,
        .tick = game_tick,
        .enter_phase = game_enter_phase,
        .render_phase = game_render_phase,
    };

    /* Zero mutes the coin callback;
     * use a command in 4..127 only after implementing it in your sound driver.
     * Unsigned supplies player_start and coin_sound: do not duplicate them here. */
    /* Each entry dispatches the BIOS USER request and initializes the platform
     * before game_initialize. Returning hands lifecycle control back to the BIOS. */
    return mvs_title ? unsigned_neo_geo_main_mvs(&runtime, 0u) : unsigned_neo_geo_main(&runtime, 0u);
}

/* Standard BIOS entry: dispatch USER 1/2 and let the runtime handle START. */
int main(void) {
    return game_run(false);
}

/* Keep this ngdevkit entry point for the MVS BIOS title transition.
 * USER 3 prepares the cartridge sound driver and runs the title flow. */
int main_mvs_title(void) {
    return game_run(true);
}
