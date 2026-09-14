import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { GameHud } from "@/components/GameHud";
import { HarthYard, type HudAction, type HudSnap, type MenuCmd } from "@/game/engine";

export const Route = createFileRoute("/")({ component: Home });

const empty: HudSnap = {
  hp: 100,
  coin: 4,
  spark: 0,
  heat: 0,
  steel: 0,
  shadow: 0,
  tongue: 0,
  sparkStat: 0,
  prompt: "",
  log: [],
  talk: null,
  overlay: "cinematic",
  path: "none",
  phase: "boot",
  invited: false,
  day: false,
  menu: "root",
};

function Home() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const gameRef = useRef<HarthYard | null>(null);
  const [hud, setHud] = useState<HudSnap>(empty);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const game = new HarthYard(canvas, setHud);
    gameRef.current = game;
    game.resize();
    game.start();
    const onResize = () => game.resize();
    addEventListener("resize", onResize);
    return () => {
      removeEventListener("resize", onResize);
      game.dispose();
      gameRef.current = null;
    };
  }, []);

  return (
    <main className="relative h-dvh w-full overflow-hidden bg-night touch-none">
      <canvas ref={canvasRef} className="block h-full w-full [image-rendering:pixelated]" />
      <GameHud
        hud={hud}
        onPlay={() => gameRef.current?.requestPlay()}
        onMenu={(cmd: MenuCmd) => gameRef.current?.menu(cmd)}
        onAction={(a: HudAction) => gameRef.current?.tap(a)}
        onChoice={(id: string) => gameRef.current?.choose(id)}
        onStick={(dx, dy) => gameRef.current?.setStick(dx, dy)}
        onStickEnd={() => gameRef.current?.clearStick()}
      />
    </main>
  );
}
