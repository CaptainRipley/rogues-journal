import type { HudAction, HudSnap, MenuCmd, PathId } from "@/game/engine";

type Props = {
  hud: HudSnap;
  onPlay: () => void;
  onMenu: (cmd: MenuCmd) => void;
  onAction: (a: HudAction) => void;
  onChoice: (id: string) => void;
  onStick: (dx: number, dy: number) => void;
  onStickEnd: () => void;
};

const PATH_LABEL: Record<PathId, string> = {
  none: "Harth",
  steel: "The sword",
  song: "The lute",
  spark: "The book",
  feather: "Feather hands",
};

export function GameHud({ hud, onPlay, onMenu, onAction, onChoice, onStick, onStickEnd }: Props) {
  return (
    <div className="pointer-events-none absolute inset-0 text-page">
      <div className="absolute left-4 top-3 font-display text-xs uppercase tracking-[0.22em] text-gold">
        Rogue's Journal · {PATH_LABEL[hud.path]}
        {hud.invited ? " · Invited" : ""}
      </div>

      {hud.overlay === "none" ? (
        <div className="absolute left-1/2 top-1/2 h-2.5 w-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full border border-page/50" />
      ) : null}

      {hud.overlay === "none" || hud.overlay === "paused" ? (
        <div className="absolute bottom-20 left-4 font-body text-sm leading-relaxed drop-shadow tabular-nums md:bottom-5">
          HP <span className="text-gold">{Math.max(0, hud.hp | 0)}</span>
          &nbsp; Coin <span className="text-gold">{hud.coin}</span>
          {hud.path === "spark" ? (
            <>
              &nbsp; Spark <span className="text-gold">{hud.spark}</span>
            </>
          ) : null}
          <div className="text-muted">
            Heat {hud.heat}
            {hud.path === "steel" ? ` · Steel ${hud.steel}` : ""}
            {hud.path === "feather" ? ` · Shadow ${hud.shadow}` : ""}
            {hud.path === "song" ? ` · Tongue ${hud.tongue}` : ""}
          </div>
        </div>
      ) : null}

      {hud.prompt && hud.overlay === "none" ? (
        <div className="absolute bottom-24 left-1/2 w-[min(28rem,92vw)] -translate-x-1/2 text-center font-body text-sm text-page-dim">
          {hud.prompt}
        </div>
      ) : null}

      <div className="absolute right-4 bottom-5 hidden w-72 text-right font-body text-sm text-page-dim md:block">
        {hud.log.map((m, i) => (
          <div key={`${i}-${m}`}>{m}</div>
        ))}
      </div>

      {hud.talk && hud.overlay === "none" ? (
        <div className="pointer-events-none absolute bottom-28 left-1/2 w-[min(34rem,92vw)] -translate-x-1/2 border border-border bg-surface px-4 py-3 font-body text-page">
          <div className="font-display text-sm tracking-wide text-gold">{hud.talk.name}</div>
          <div className="mt-1 leading-relaxed">{hud.talk.line}</div>
          {hud.talk.choices?.length ? (
            <div className="mt-3 flex flex-col gap-1.5">
              {hud.talk.choices.map((c, i) => (
                <button
                  key={c.id}
                  type="button"
                  onClick={() => onChoice(c.id)}
                  className="pointer-events-auto border border-gold/35 bg-gold/10 px-3 py-1.5 text-left font-body text-sm text-gold hover:bg-gold/20"
                >
                  {i + 1}. {c.label}
                </button>
              ))}
            </div>
          ) : null}
        </div>
      ) : null}

      {hud.overlay !== "none" ? (
        <div className="pointer-events-auto absolute inset-0 flex items-center justify-center bg-night/80 text-left">
          <div className="max-w-md px-6">
            <h1 className="font-display text-2xl uppercase tracking-[0.2em] text-gold">Rogue's Journal</h1>
            {hud.overlay === "cinematic" ? (
              <>
                <p className="mt-3 font-display text-lg text-page">The cinematic opens later.</p>
                <p className="mt-2 font-body text-page-dim leading-relaxed">
                  A cart. Spears. Mara looking back once. Then the ditch, and a fairy who does not work for free.
                </p>
                <div className="mt-5 flex flex-col gap-2">
                  <button
                    type="button"
                    onClick={onPlay}
                    className="border border-gold/50 bg-gold/10 px-4 py-2.5 font-display text-sm tracking-wide text-gold"
                  >
                    Wake in the mud
                  </button>
                  <a
                    href="/godot/index.html"
                    className="border border-border bg-surface px-4 py-2.5 font-display text-sm tracking-wide text-page"
                  >
                    Play the Godot 4.7 build
                  </a>
                </div>
                <ul className="mt-4 space-y-1 font-body text-sm text-muted">
                  <li>WASD move · mouse look · Space jump</li>
                  <li>E take / talk · F pickpocket Nix</li>
                  <li>On a phone: left stick, right drag to look</li>
                </ul>
              </>
            ) : hud.overlay === "dead" ? (
              <button type="button" onClick={onPlay} className="mt-3 font-body text-page-dim leading-relaxed">
                The page ends in the mud. Tap to write it again.
              </button>
            ) : (
              <PauseMenu hud={hud} onMenu={onMenu} />
            )}
          </div>
        </div>
      ) : (
        <MobilePad hud={hud} onAction={onAction} onStick={onStick} onStickEnd={onStickEnd} />
      )}
    </div>
  );
}

function MenuBtn({ label, onClick, dim }: { label: string; onClick: () => void; dim?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full border px-4 py-2.5 text-left font-display text-sm tracking-wide ${
        dim ? "border-border bg-surface text-page-dim" : "border-gold/50 bg-gold/10 text-gold"
      }`}
    >
      {label}
    </button>
  );
}

function PauseMenu({ hud, onMenu }: { hud: HudSnap; onMenu: (cmd: MenuCmd) => void }) {
  if (hud.menu === "settings") {
    return (
      <div className="mt-4 flex w-72 flex-col gap-2">
        <p className="font-body text-page-dim leading-relaxed">Settings. Placeholder. The journal has no knobs yet, only mud.</p>
        <MenuBtn label="Back" onClick={() => onMenu("back")} dim />
      </div>
    );
  }
  if (hud.menu === "god") {
    return (
      <div className="mt-4 flex w-72 flex-col gap-2">
        <p className="font-body text-page-dim">God mode. Sky answers to you.</p>
        <p className="font-display text-xs uppercase tracking-[0.2em] text-gold">Now: {hud.day ? "Day" : "Night"}</p>
        <MenuBtn label="Day" onClick={() => onMenu("day")} />
        <MenuBtn label="Night" onClick={() => onMenu("night")} />
        <MenuBtn label="Back" onClick={() => onMenu("back")} dim />
      </div>
    );
  }
  return (
    <div className="mt-4 flex w-72 flex-col gap-2">
      <p className="mb-1 font-body text-page-dim">The wall can wait.</p>
      <MenuBtn label="Resume" onClick={() => onMenu("resume")} />
      <MenuBtn label="Settings" onClick={() => onMenu("settings")} dim />
      <MenuBtn label="God mode" onClick={() => onMenu("god")} />
      <MenuBtn label="Quit game" onClick={() => onMenu("quit")} dim />
    </div>
  );
}

function MobilePad({
  hud,
  onAction,
  onStick,
  onStickEnd,
}: {
  hud: HudSnap;
  onAction: Props["onAction"];
  onStick: Props["onStick"];
  onStickEnd: Props["onStickEnd"];
}) {
  const actions: [HudAction, string][] =
    hud.phase === "gift"
      ? [
          ["jump", "Jump"],
          ["talk", "Take"],
          ["pocket", "Pockets"],
        ]
      : hud.path === "steel"
        ? [
            ["jump", "Jump"],
            ["sword", "Sword"],
            ["talk", "Talk"],
          ]
        : hud.path === "spark"
          ? [
              ["jump", "Jump"],
              ["spark", "Spark"],
              ["talk", "Talk"],
            ]
          : hud.path === "song"
            ? [
                ["jump", "Jump"],
                ["song", "Play"],
                ["talk", "Talk"],
              ]
            : hud.path === "feather"
              ? [
                  ["jump", "Jump"],
                  ["pocket", "Pocket"],
                  ["talk", "Talk"],
                ]
              : [["jump", "Jump"]];

  return (
    <div className="pointer-events-none absolute inset-0">
      <div
        className="pointer-events-auto absolute bottom-6 left-6 h-28 w-28 rounded-full border border-border bg-surface/80 md:hidden"
        onTouchStart={(e) => {
          e.preventDefault();
          const r = e.currentTarget.getBoundingClientRect();
          const t = e.changedTouches[0];
          onStick((t.clientX - (r.left + r.width / 2)) / 50, (t.clientY - (r.top + r.height / 2)) / 50);
        }}
        onTouchMove={(e) => {
          e.preventDefault();
          const r = e.currentTarget.getBoundingClientRect();
          const t = e.changedTouches[0];
          onStick((t.clientX - (r.left + r.width / 2)) / 50, (t.clientY - (r.top + r.height / 2)) / 50);
        }}
        onTouchEnd={onStickEnd}
      />
      <div className="pointer-events-auto absolute right-4 bottom-6 grid grid-cols-2 gap-2 md:hidden">
        {actions.map(([id, label]) => (
          <button
            key={id}
            type="button"
            className="min-h-11 min-w-16 border border-border bg-surface px-3 font-display text-sm text-gold"
            onPointerDown={(e) => {
              e.preventDefault();
              onAction(id);
            }}
          >
            {label}
          </button>
        ))}
      </div>
    </div>
  );
}
