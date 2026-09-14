import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

export type PathId = "none" | "steel" | "song" | "spark" | "feather";
export type Phase = "boot" | "wake" | "gift" | "play";
export type HudAction = "jump" | "sword" | "spark" | "talk" | "pocket" | "song";
export type MenuCmd = "resume" | "settings" | "god" | "day" | "night" | "back" | "quit";
export type MenuPage = "root" | "settings" | "god";

export type HudSnap = {
  hp: number;
  coin: number;
  spark: number;
  heat: number;
  steel: number;
  shadow: number;
  tongue: number;
  sparkStat: number;
  prompt: string;
  log: string[];
  talk: { name: string; line: string; choices?: { id: string; label: string }[] } | null;
  overlay: "cinematic" | "paused" | "dead" | "none";
  path: PathId;
  phase: Phase;
  invited: boolean;
  day: boolean;
  menu: MenuPage;
};

type Npc = {
  id: string;
  name: string;
  color: number;
  skin: number;
  mesh: THREE.Group;
  hp: number;
  purse: number;
  hostile: boolean;
  hitCd: number;
  wanderT: number;
  picked: boolean;
  charmed: boolean;
  guard: boolean;
  ally: boolean;
  lines: string[];
  kind: "person" | "critter" | "hound";
  sitT: number;
};

type Gift = {
  id: Exclude<PathId, "none" | "feather">;
  mesh: THREE.Group;
  hint: string;
};

type Fairy = {
  mesh: THREE.Group;
  wings: THREE.Mesh[];
  t: number;
  gone: boolean;
};

type Solid = { min: THREE.Vector3; max: THREE.Vector3 };
type Bolt = { mesh: THREE.Mesh; vel: THREE.Vector3; life: number };

const _fwd = new THREE.Vector3();
const _right = new THREE.Vector3();
const _wish = new THREE.Vector3();
const _ppos = new THREE.Vector3();
const _tmp = new THREE.Vector3();
const _up = new THREE.Vector3(0, 1, 0);
const _quat = new THREE.Quaternion();

const DITCH = { x: 0, z: 28.8 };
const HOUSES: { x: number; z: number; w: number; d: number }[] = [
  { x: -9.2, z: 21.5, w: 7.2, d: 6.2 },
  { x: -9.2, z: 14.2, w: 7.2, d: 6.4 },
  { x: -9.4, z: 6.4, w: 7.8, d: 7.2 },
  { x: -9.6, z: -2.2, w: 8.2, d: 7.6 },
  { x: -9.0, z: -11.6, w: 6.8, d: 5.6 },
  { x: 9.2, z: 21.5, w: 7.2, d: 6.2 },
  { x: 9.2, z: 14.2, w: 7.2, d: 6.4 },
  { x: 9.6, z: 6.2, w: 8.4, d: 8.4 },
  { x: 9.4, z: -3.4, w: 8.0, d: 7.4 },
  { x: 8.8, z: -12.0, w: 6.6, d: 5.4 },
  { x: -3.6, z: 4.2, w: 2.6, d: 2.2 },
];
const STAND_Y = 1.7;
const LIE_Y = 0.38;

const NIX_LINES = [
  "Up, ditch-rat. Aldric took her in a cart. I took offense. Different crimes.",
  "Steel, song, or spark. Pick a gift. Or pick a pocket — I am not your mother.",
  "The sword is for people who think a door is a conversation.",
  "The lute gets you invited. Smile when you lie. It's cheaper than a seal.",
  "The book bites. Point it at problems. The king's drapes are not fireproof.",
  "And if your hands wander toward my coat, don't blame the mud.",
];

const HOB_TALK: Record<string, { line: string; choices: { id: string; label: string }[] }> = {
  open: {
    line: "Road tax. Feast night. Double, unless you're expected. You look like a man who lost a wife and found a ditch. That's not a deduction.",
    choices: [
      { id: "wife", label: "Aldric took my wife. I need the gate." },
      { id: "bribe", label: "How much to look the other way?" },
      { id: "hire", label: "Walk with me. I'll make you richer than a tax." },
      { id: "leave", label: "Keep the road. I'll keep my coin." },
    ],
  },
  wife: {
    line: "Everyone's wife is at the party. His Generous Majesty collects them like overdue stamps. Bren likes complaints. Cole likes lists. Neither likes husbands.",
    choices: [
      { id: "hire", label: "Then come with me. You know who takes the bribes." },
      { id: "who", label: "Who else hates him tonight?" },
      { id: "leave", label: "I'll take my chances." },
    ],
  },
  who: {
    line: "Marta waters the cups. Pell keeps a key she shouldn't. Ralf is already Cousin-of-a-Baron, drunk. Me? I hate the paperwork. The king is a very tall form.",
    choices: [
      { id: "hire", label: "Hate the form with me." },
      { id: "leave", label: "I'll start with Marta." },
    ],
  },
  bribe: {
    line: "Four coins looks the other way. Six writes you onto a list that did not exist this morning. Or you can hire the man who writes the list.",
    choices: [
      { id: "pay4", label: "Four coins. Look away." },
      { id: "pay6", label: "Six coins. Put me on the list." },
      { id: "hire", label: "Keep the coin. Draw a sword instead." },
    ],
  },
  hire: {
    line: "Join you? I collect coins, not corpses. Unless the corpses were already late on Tuesday. What's in it besides a ditch and a king?",
    choices: [
      { id: "recruit_steal", label: "He steals from you every feast night. Tonight we steal back." },
      { id: "recruit_split", label: "Whatever we lift, we split. I need a clerk with a knife." },
      { id: "coward", label: "Coward." },
    ],
  },
  coward: {
    line: "That's a professional assessment. I'll be here, counting. Try not to become a line item.",
    choices: [
      { id: "recruit_steal", label: "I take it back. Walk with me." },
      { id: "leave", label: "Stay counting." },
    ],
  },
  recruited: {
    line: "Fine. I am an official accompaniment. If anyone asks, you hired a clerk. Clerks bleed like anyone. I'll hit what hits you.",
    choices: [{ id: "leave", label: "Stay close." }],
  },
  paid4: {
    line: "That's a permit. Don't tell the tune. The gate still has eyes. I don't.",
    choices: [
      { id: "leave", label: "Good." },
      { id: "hire", label: "Change of plan. Come with me." },
    ],
  },
  paid6: {
    line: "You're expected. You were always expected. I just hadn't written it yet. Don't make me erase you.",
    choices: [
      { id: "leave", label: "See you at the gate." },
      { id: "recruit_split", label: "Walk me there." },
    ],
  },
  broke: {
    line: "That's pocket lint. Come back when you've robbed someone honest. I don't take IOUs from ditches.",
    choices: [
      { id: "hire", label: "Then work it off. Walk with me." },
      { id: "leave", label: "I'll be back." },
    ],
  },
  ally: {
    line: "Still breathing. Good. I charge extra for funerals. Point me at a problem if you've got one.",
    choices: [
      { id: "leave", label: "Stay on my shoulder." },
      { id: "ally_gate", label: "About the gate." },
    ],
  },
  ally_gate: {
    line: "Bren unlatches the kitchen on the second bell. Cole believes in lists. I believe in not being the body they count. I'll swing if they swing.",
    choices: [{ id: "leave", label: "That's the job." }],
  },
};

const DOG_TALK: Record<string, { line: string; choices: { id: string; label: string }[] }> = {
  open: {
    line: "The hound wheezes like a bellows that filed for retirement. One ear is considering you. The other is union.",
    choices: [
      { id: "pet", label: "Scratch behind the ear." },
      { id: "ask", label: "Ask if he's seen a stolen wife." },
      { id: "leave", label: "Leave the old man to his dirt." },
    ],
  },
  pet: {
    line: "He sits. The whole sagging cathedral of him. A tail thumps once, as if tax has been waived.",
    choices: [
      { id: "petmore", label: "Again. He earned it." },
      { id: "leave", label: "That's enough dignity for one night." },
    ],
  },
  petmore: {
    line: "A groan. Then he leans the entire failed kingdom of his head into your palm. Somewhere a king is not being pet.",
    choices: [{ id: "leave", label: "Good boy. Worse king." }],
  },
  ask: {
    line: "He smells the ditch on you. Then the inn. Then pity. No wife in that nose. Only gravy, and a rat he has already forgiven.",
    choices: [
      { id: "pet", label: "Scratch him anyway." },
      { id: "leave", label: "Keep sniffing, soldier." },
    ],
  },
};

const CHARM: Record<string, string> = {
  hob: "Hob winces. 'That's a permit, I guess. Don't tell the tune.'",
  marta: "Marta taps the bar. 'If he wanted music he should have paid for less desperation.'",
  bren: "Bren's jaw unclenches. 'Entertainment. Side door. If anyone asks, you whistle.'",
  cole: "Cole nods like a man who has suffered lutes. 'You're on the list. Barely.'",
  pell: "Pell: 'That was not a hymn. I will pretend it was.'",
  ralf: "Ralf weeps. 'Cousin! You brought the orchards with you!'",
};

export class HarthYard {
  readonly canvas: HTMLCanvasElement;
  private renderer: THREE.WebGLRenderer;
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private yawObj = new THREE.Object3D();
  private sword = new THREE.Group();
  private lute = new THREE.Group();
  private book = new THREE.Group();
  private solids: Solid[] = [];
  private npcs: Npc[] = [];
  private gifts: Gift[] = [];
  private fairy: Fairy | null = null;
  private bolts: Bolt[] = [];
  private keys = new Set<string>();
  private injected = new Set<string>();
  private locked = false;
  private hadLock = false;
  private coarse = false;
  private running = false;
  private raf = 0;
  private last = 0;
  private yaw = 0;
  private pitch = 0.95;
  private vel = new THREE.Vector3();
  private grounded = false;
  private swinging = 0;
  private strumming = 0;
  private spellCd = 0;
  private invuln = 0;
  private sparkRegen = 0;
  private clock = 0;
  private wakeT = 0;
  private phase: Phase = "boot";
  private path: PathId = "none";
  private invited = false;
  private fairyTalk: string | null = NIX_LINES[0];
  private lookTouch: { id: number; x: number; y: number } | null = null;
  private stick: { id: number; x: number; y: number; dx: number; dy: number } | null = null;
  private hud: HudSnap;
  private onHud: (s: HudSnap) => void;
  private logs: string[] = [];
  private talkOn: Npc | null = null;
  private hobNode: string | null = null;
  private dogNode: string | null = null;
  private lastHudKey = "";
  private audio: AudioContext | null = null;
  private noise!: THREE.CanvasTexture;
  private mudMat!: THREE.MeshStandardMaterial;
  private stoneMat!: THREE.MeshStandardMaterial;
  private woodMat!: THREE.MeshStandardMaterial;
  private nixMat!: THREE.SpriteMaterial;
  private pineProto: THREE.Object3D | null = null;
  private hauntedTrees: THREE.Object3D[] = [];
  private hauntedBushes: THREE.Object3D[] = [];
  private grassMats: THREE.MeshBasicMaterial[] = [];
  private castlePieces = new Map<string, THREE.Object3D>();
  private day = false;
  private bgMesh!: THREE.Mesh<THREE.CylinderGeometry, THREE.MeshBasicMaterial>;
  private menuPage: MenuPage = "root";
  private hemi!: THREE.HemisphereLight;
  private sun!: THREE.DirectionalLight;
  private skyMat!: THREE.MeshBasicMaterial;
  private clouds: THREE.Sprite[] = [];
  private stars!: THREE.Points;
  private fires: { light: THREE.PointLight; flame: THREE.Object3D; base: number; seed: number }[] = [];

  private player = {
    hp: 100,
    coin: 4,
    spark: 0,
    heat: 0,
    steel: 0,
    shadow: 0,
    tongue: 0,
    sparkStat: 0,
  };

  constructor(canvas: HTMLCanvasElement, onHud: (s: HudSnap) => void) {
    this.canvas = canvas;
    this.onHud = onHud;
    this.coarse = window.matchMedia?.("(pointer: coarse)").matches ?? false;
    this.hud = this.snap("cinematic");

    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: false });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1));
    this.renderer.setSize(canvas.clientWidth, canvas.clientHeight, false);
    this.renderer.shadowMap.enabled = false;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.32;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x07080a);
    this.scene.fog = new THREE.Fog(0x120f0c, 16, 62);

    this.camera = new THREE.PerspectiveCamera(75, 1, 0.08, 200);
    this.camera.position.set(0, 0, 0);
    this.yawObj.position.set(DITCH.x, LIE_Y, DITCH.z);
    this.yawObj.add(this.camera);
    this.scene.add(this.yawObj);

    this.initArt();
    this.buildWorld();
    this.buildDitch();
    this.buildViewmodels();
    this.bind();
    this.installProbe();
    this.emit();
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.last = performance.now();
    const loop = (now: number) => {
      if (!this.running) return;
      const dt = Math.min(0.05, (now - this.last) / 1000);
      this.last = now;
      this.tick(dt);
      this.renderer.render(this.scene, this.camera);
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);
  }

  dispose() {
    this.running = false;
    cancelAnimationFrame(this.raf);
    this.unbind();
    this.renderer.dispose();
    delete window.__controlsTest;
  }

  resize() {
    const w = this.canvas.clientWidth || 1;
    const h = this.canvas.clientHeight || 1;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1));
    this.renderer.setSize(w, h, false);
  }

  requestPlay() {
    this.tone(140, 0.08);
    if (this.player.hp <= 0) this.resetIfDead();
    if (this.phase === "boot") {
      this.phase = "wake";
      this.wakeT = 0;
      this.yawObj.position.set(DITCH.x, LIE_Y, DITCH.z);
      this.yaw = 0;
      this.pitch = 0.95;
      this.fairyTalk = NIX_LINES[0];
      this.log("Rain in the mouth. A light with opinions.");
    }
    const el = this.canvas;
    const req = el.requestPointerLock as (opts?: { unadjustedMovement?: boolean }) => Promise<void> | void;
    try {
      const p = req.call(el, { unadjustedMovement: true });
      if (p && typeof (p as Promise<void>).catch === "function") {
        (p as Promise<void>).catch(() => req.call(el));
      }
    } catch {
      req.call(el);
    }
    this.emit();
  }

  menu(cmd: MenuCmd) {
    if (cmd === "resume") {
      this.menuPage = "root";
      this.requestPlay();
      return;
    }
    if (cmd === "settings") {
      this.menuPage = "settings";
      this.emit();
      return;
    }
    if (cmd === "god") {
      this.menuPage = "god";
      this.emit();
      return;
    }
    if (cmd === "back") {
      this.menuPage = "root";
      this.emit();
      return;
    }
    if (cmd === "day") {
      this.day = true;
      this.applyTime();
      this.log("God mode. The sun is a cheat.");
      this.emit();
      return;
    }
    if (cmd === "night") {
      this.day = false;
      this.applyTime();
      this.log("God mode. Night takes the yard back.");
      this.emit();
      return;
    }
    if (cmd === "quit") {
      document.exitPointerLock();
      this.locked = false;
      this.hadLock = false;
      this.menuPage = "root";
      this.phase = "boot";
      this.emit();
    }
  }

  private buildSky() {
    this.skyMat = new THREE.MeshBasicMaterial({
      color: 0x0c1016,
      side: THREE.BackSide,
      fog: false,
      depthWrite: false,
    });
    const dome = new THREE.Mesh(new THREE.SphereGeometry(110, 16, 12), this.skyMat);
    this.scene.add(dome);

    const starGeo = new THREE.BufferGeometry();
    const starPos = new Float32Array(180 * 3);
    for (let i = 0; i < 180; i++) {
      const th = Math.random() * Math.PI * 2;
      const ph = 0.15 + Math.random() * 1.1;
      starPos[i * 3] = Math.sin(ph) * Math.cos(th) * 90;
      starPos[i * 3 + 1] = Math.cos(ph) * 90;
      starPos[i * 3 + 2] = Math.sin(ph) * Math.sin(th) * 90;
    }
    starGeo.setAttribute("position", new THREE.BufferAttribute(starPos, 3));
    this.stars = new THREE.Points(
      starGeo,
      new THREE.PointsMaterial({ color: 0xd8d0c4, size: 0.55, sizeAttenuation: true, fog: false }),
    );
    this.scene.add(this.stars);

    const places: [number, number, number, number][] = [
      [-28, 38, -40, 1],
      [18, 34, -48, 2],
      [42, 36, -20, 3],
      [-40, 32, 10, 1],
      [8, 40, 30, 2],
      [-12, 36, -8, 3],
      [30, 33, 22, 1],
    ];
    for (const [x, y, z, n] of places) {
      const s = this.bitSprite(`/art/cloud${n}.png`, 22, 10, 0);
      s.position.set(x, y, z);
      s.material.fog = false;
      s.material.opacity = 0.85;
      s.material.transparent = true;
      this.scene.add(s);
      this.clouds.push(s);
    }
    this.buildBackdrop();
  }

  private buildBackdrop() {
    const mat = new THREE.MeshBasicMaterial({
      side: THREE.BackSide,
      fog: false,
      depthWrite: false,
    });
    this.bgMesh = new THREE.Mesh(new THREE.CylinderGeometry(82, 82, 36, 24, 1, true), mat);
    this.bgMesh.position.y = 14;
    this.scene.add(this.bgMesh);
    new THREE.TextureLoader().load("/art/bg/1.png", (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      t.wrapS = THREE.RepeatWrapping;
      t.wrapT = THREE.ClampToEdgeWrapping;
      t.repeat.set(-1, 1);
      this.bgMesh.material.map = t;
      this.bgMesh.material.needsUpdate = true;
    });
    for (const c of this.clouds) c.visible = false;
  }

  private applyTime() {
    if (this.day) {
      this.scene.background = new THREE.Color(0x6a7a88);
      this.scene.fog = new THREE.Fog(0x7a7268, 36, 130);
      this.skyMat.color.set(0x6e8294);
      this.hemi.color.set(0xd0c8b4);
      this.hemi.groundColor.set(0x3a2a18);
      this.hemi.intensity = 1.15;
      this.sun.color.set(0xf0d8a0);
      this.sun.intensity = 1.35;
      this.sun.position.set(30, 50, 12);
      this.stars.visible = false;
      for (const c of this.clouds) {
        c.visible = false;
      }
    } else {
      this.scene.background = new THREE.Color(0x0a0c10);
      this.scene.fog = new THREE.Fog(0x16120f, 22, 88);
      this.skyMat.color.set(0x0c1018);
      this.hemi.color.set(0x4a5460);
      this.hemi.groundColor.set(0x1a120c);
      this.hemi.intensity = 0.42;
      this.sun.color.set(0x8890a0);
      this.sun.intensity = 0.18;
      this.sun.position.set(-20, 30, 10);
      this.stars.visible = !this.day;
      for (const c of this.clouds) {
        c.visible = false;
      }
    }
  }

  setStick(dx: number, dy: number) {
    if (!this.stick) this.stick = { id: -1, x: 0, y: 0, dx: 0, dy: 0 };
    this.stick.dx = dx;
    this.stick.dy = dy;
  }

  clearStick() {
    this.stick = null;
  }

  tap(action: HudAction) {
    if (action === "jump") {
      this.keys.add("Space");
      window.setTimeout(() => this.keys.delete("Space"), 180);
    }
    if (action === "sword") this.swing();
    if (action === "spark") this.cast();
    if (action === "song") this.playTune();
    if (action === "talk") this.doTalk();
    if (action === "pocket") this.doPocket();
  }

  choose(id: string) {
    if (this.dogNode) this.applyDogChoice(id);
    else this.applyHobChoice(id);
  }

  private has(code: string) {
    return this.keys.has(code) || this.injected.has(code);
  }

  private installProbe() {
    window.__controlsTest = {
      getYaw: () => this.yaw,
      getSpeed: () => Math.hypot(this.vel.x, this.vel.z),
      setKeys: (codes: string[]) => {
        this.injected = new Set(codes);
      },
      getPos: () => ({
        x: this.yawObj.position.x,
        y: this.yawObj.position.y,
        z: this.yawObj.position.z,
        phase: this.phase,
        path: this.path,
      }),
      act: (a: HudAction) => this.tap(a),
    };
  }

  private resetIfDead() {
    if (this.player.hp > 0 && this.hud.overlay !== "dead") return;
    this.player.hp = 100;
    this.player.spark = this.path === "spark" ? 6 : 0;
    this.player.heat = 0;
    this.vel.set(0, 0, 0);
    this.yawObj.position.set(DITCH.x, STAND_Y, DITCH.z);
    this.yaw = 0;
    this.pitch = 0;
    this.phase = this.path === "none" ? "gift" : "play";
    for (const n of this.npcs) {
      n.hp = n.guard ? 55 : 40;
      n.hostile = false;
      n.ally = false;
      n.picked = false;
      n.charmed = false;
      n.mesh.visible = true;
      n.mesh.position.copy((n.mesh.userData.home as THREE.Vector3) ?? n.mesh.position);
    }
    this.log("Rain on stone. The wall is waiting.");
  }

  private log(msg: string) {
    this.logs.unshift(msg);
    if (this.logs.length > 5) this.logs.pop();
  }

  private snap(overlay: HudSnap["overlay"]): HudSnap {
    return {
      ...this.player,
      prompt: "",
      log: [...this.logs],
      talk: this.fairyTalk ? { name: "Nix", line: this.fairyTalk } : null,
      overlay,
      path: this.path,
      phase: this.phase,
      invited: this.invited,
      day: this.day,
      menu: this.menuPage,
    };
  }

  private overlayNow(): HudSnap["overlay"] {
    if (this.player.hp <= 0) return "dead";
    if (this.phase === "boot") return "cinematic";
    if (this.locked || this.stick || this.coarse) return "none";
    if (this.phase === "wake") return "none";
    if (this.hadLock) return "paused";
    return "none";
  }

  private emit(prompt = "") {
    const talk = this.dialogTalk();
    const overlay = this.overlayNow();
    const key = [
      this.player.hp,
      this.player.coin,
      this.player.spark,
      this.player.heat,
      overlay,
      this.path,
      this.phase,
      prompt,
      talk?.line ?? "",
      (talk?.choices ?? []).map((c) => c.id).join(","),
      this.logs[0] ?? "",
      this.invited ? 1 : 0,
      this.day ? 1 : 0,
      this.menuPage,
    ].join("|");
    if (key === this.lastHudKey) return;
    this.lastHudKey = key;
    this.hud = {
      ...this.player,
      prompt,
      log: [...this.logs],
      talk,
      overlay,
      path: this.path,
      phase: this.phase,
      invited: this.invited,
      day: this.day,
      menu: this.menuPage,
    };
    this.onHud(this.hud);
  }

  private initArt() {
    this.noise = this.makeNoise();
    this.mudMat = this.ps1(0x8a7a62, 18);
    this.stoneMat = this.ps1(0xffffff, 3);
    this.woodMat = this.ps1(0x5a4030, 3);
    this.nixMat = new THREE.SpriteMaterial({
      transparent: true,
      depthWrite: false,
      color: 0xffffff,
      fog: false,
    });
    const loader = new THREE.TextureLoader();
    loader.load("/art/mud.png", (t) => {
      this.prep(t, 36);
      this.mudMat.map = t;
      this.mudMat.color.set(0xb8a888);
      this.mudMat.needsUpdate = true;
    });
    loader.load("/art/stone.png", (t) => {
      this.prep(t, 3);
      this.stoneMat.map = t;
      this.stoneMat.needsUpdate = true;
    });
    loader.load("/art/nix.png", (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      t.needsUpdate = true;
      this.nixMat.map = t;
      this.nixMat.needsUpdate = true;
      if (this.fairy) {
        for (const c of this.fairy.mesh.children) {
          if ((c as THREE.Mesh).isMesh && !(c as THREE.Sprite).isSprite) {
            const name = c.type;
            if (name !== "PointLight" && name !== "Sprite") c.visible = false;
          }
        }
        this.fairy.wings.forEach((w) => {
          w.visible = false;
        });
      }
    });
    this.bootPsxNature();
    this.bootCastle();
  }

  private bootPsxNature() {
    for (const name of ["grass_1", "grass_2", "grass_3", "grass_4", "grass_5", "grass_6"]) {
      this.grassMats.push(this.psxAlpha(`/models/psx-nature/${name}.png`));
    }
    const loader = new GLTFLoader();
    const trees = ["tree1", "tree2", "tree3", "tree4", "tree5"];
    const bushes = ["bush1", "bush2", "bush3", "bush5", "bush6"];
    let left = trees.length + bushes.length;
    const done = () => {
      left -= 1;
      if (left <= 0) this.plantForest();
    };
    const grab = (file: string, into: THREE.Object3D[]) => {
      loader.load(
        `/models/psx-nature/haunted/${file}.glb`,
        (gltf) => {
          this.crunchMats(gltf.scene);
          into.push(gltf.scene);
          done();
        },
        undefined,
        done,
      );
    };
    trees.forEach((f) => grab(f, this.hauntedTrees));
    bushes.forEach((f) => grab(f, this.hauntedBushes));
  }

  private bootCastle() {
    new GLTFLoader().load("/models/castle/Castles_and_Forts.glb", (gltf) => {
      this.crunchMats(gltf.scene, false);
      for (const ch of gltf.scene.children) {
        if (ch.name) this.castlePieces.set(ch.name, ch);
      }
      this.buildCastleGate();
    });
  }

  private castlePiece(name: string, x: number, y: number, z: number, yaw: number, s: number) {
    const src = this.castlePieces.get(name);
    if (!src) return;
    const n = src.clone();
    n.position.set(x, y, z);
    n.rotation.set(0, yaw, 0);
    n.scale.setScalar(s);
    this.scene.add(n);
  }

  private buildCastleGate() {
    if (!this.castlePieces.size) return;
    const S = 2.5;
    const z = -21.2;
    const yaw = Math.PI / 2;
    this.castlePiece("Gate_2x4_doorway", 0, 0, z, yaw, S);
    this.castlePiece("Gate_Door", -0.7, 0, z + 0.15, yaw, S);
    this.castlePiece("Gate_Door", 0.7, 0, z + 0.15, yaw + Math.PI, S);
    for (const side of [-1, 1] as const) {
      const tx = side * 6.6;
      this.castlePiece("Tower_Mid", tx, 0, z, 0, S);
      this.castlePiece("Tower_top_1", tx, 2 * S, z, 0, S);
      this.castlePiece("Roof_Cone", tx, 4.15 * S, z, 0, S);
      this.wallTorch(tx + side * 1.1, 3.4, z + 1.3, "s");
      for (let i = 0; i < 3; i++) {
        const wx = side * (12.2 + i * 10);
        const wall = i === 2 ? "Wall_2x4_ruined" : "Wall_2x4";
        this.castlePiece(wall, wx, 0, z, yaw, S);
        this.castlePiece("Wall_2x4_walkway", wx, 2 * S, z, yaw, S);
      }
      const ex = side * 38;
      this.castlePiece("Tower_Mid", ex, 0, z, 0, S);
      this.castlePiece("Tower_top_1", ex, 2 * S, z, 0, S);
      this.castlePiece("Roof_Cone", ex, 4.15 * S, z, 0, S);
    }
    this.solids.push({
      min: new THREE.Vector3(-40, 0, z - 1.4),
      max: new THREE.Vector3(-2.4, 8, z + 1.4),
    });
    this.solids.push({
      min: new THREE.Vector3(2.4, 0, z - 1.4),
      max: new THREE.Vector3(40, 8, z + 1.4),
    });
  }

  private tileMat(url: string, repeat: number, tint = 0xffffff, repeatY = repeat) {
    const mat = new THREE.MeshBasicMaterial({ color: tint, fog: true });
    new THREE.TextureLoader().load(url, (t) => {
      t.wrapS = THREE.RepeatWrapping;
      t.wrapT = THREE.RepeatWrapping;
      t.repeat.set(repeat, repeatY);
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      mat.map = t;
      mat.needsUpdate = true;
    });
    return mat;
  }

  private grassPatch(x: number, z: number, w: number, d: number, mat: THREE.Material, y = 0.014) {
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(w, d), mat);
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(x, y, z);
    this.scene.add(mesh);
  }

  private cobblePath() {
    const cobble = this.tileMat("/models/psx-nature/cobble.png", 3.4, 0xd4cbb8, 18);
    this.grassPatch(0, 5, 4.4, 50, cobble, 0.018);
    for (let z = -17; z < 28; z += 2.2) {
      for (const side of [-1, 1] as const) {
        const w = 0.5 + Math.abs((z * 13) % 7) * 0.06;
        this.grassPatch(side * (2.15 + w * 0.42), z, w, 2.3, cobble, 0.017);
      }
    }
    this.grassPatch(0, 27.2, 5.4, 4.2, cobble, 0.016);
  }

  private crunchMats(root: THREE.Object3D, cut = true) {
    root.traverse((o) => {
      const mesh = o as THREE.Mesh;
      if (!mesh.isMesh) return;
      const list = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
      const next = list.map((raw) => {
        const src = raw as THREE.MeshStandardMaterial;
        const map = src.map;
        if (map) {
          map.magFilter = THREE.NearestFilter;
          map.minFilter = THREE.NearestFilter;
          map.generateMipmaps = false;
          map.colorSpace = THREE.SRGBColorSpace;
          map.needsUpdate = true;
        }
        return new THREE.MeshBasicMaterial({
          map,
          color: 0xffffff,
          transparent: cut,
          alphaTest: cut ? 0.4 : 0,
          depthWrite: true,
          side: THREE.DoubleSide,
          fog: true,
        });
      });
      mesh.material = next.length === 1 ? next[0] : next;
    });
  }

  private psxAlpha(url: string) {
    const mat = new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      alphaTest: 0.32,
      depthWrite: true,
      side: THREE.DoubleSide,
      fog: true,
    });
    new THREE.TextureLoader().load(url, (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      mat.map = t;
      mat.needsUpdate = true;
    });
    return mat;
  }

  private psxCard(url: string, x: number, z: number, w: number, h: number) {
    const mat = this.psxAlpha(url);
    const geo = new THREE.PlaneGeometry(w, h);
    const g = new THREE.Group();
    const a = new THREE.Mesh(geo, mat);
    const b = new THREE.Mesh(geo, mat);
    b.rotation.y = Math.PI / 2;
    g.add(a, b);
    g.position.set(x, h * 0.5, z);
    this.scene.add(g);
  }

  private bit(url: string) {
    const mat = new THREE.SpriteMaterial({
      transparent: true,
      depthWrite: false,
      fog: true,
      color: 0xffffff,
    });
    new THREE.TextureLoader().load(url, (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      mat.map = t;
      mat.needsUpdate = true;
    });
    return mat;
  }

  private bitSprite(url: string, w: number, h: number, y: number) {
    const s = new THREE.Sprite(this.bit(url));
    s.scale.set(w, h, 1);
    s.position.y = y;
    return s;
  }

  private held(url: string, w: number, h: number) {
    const mat = new THREE.MeshBasicMaterial({
      transparent: true,
      depthWrite: false,
      side: THREE.DoubleSide,
    });
    new THREE.TextureLoader().load(url, (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      mat.map = t;
      mat.needsUpdate = true;
    });
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
    mesh.position.y = h * 0.42;
    return mesh;
  }

  private makeNoise() {
    const size = 32;
    const c = document.createElement("canvas");
    c.width = c.height = size;
    const g = c.getContext("2d")!;
    const img = g.createImageData(size, size);
    for (let i = 0; i < img.data.length; i += 4) {
      const n = 140 + ((Math.random() * 90) | 0);
      img.data[i] = n;
      img.data[i + 1] = n;
      img.data[i + 2] = n;
      img.data[i + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    const t = new THREE.CanvasTexture(c);
    t.magFilter = THREE.NearestFilter;
    t.minFilter = THREE.NearestFilter;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.generateMipmaps = false;
    return t;
  }

  private prep(t: THREE.Texture, repeat: number) {
    t.magFilter = THREE.NearestFilter;
    t.minFilter = THREE.NearestFilter;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(repeat, repeat);
    t.colorSpace = THREE.SRGBColorSpace;
    t.generateMipmaps = false;
  }

  private ps1(color: number, repeat = 3) {
    const map = this.noise.clone();
    map.repeat.set(repeat, repeat);
    return new THREE.MeshStandardMaterial({
      color,
      map,
      roughness: 0.95,
      metalness: 0.05,
      flatShading: true,
    });
  }

  private tone(freq: number, dur = 0.12) {
    try {
      this.audio ??= new AudioContext();
      if (this.audio.state === "suspended") void this.audio.resume();
      const o = this.audio.createOscillator();
      const g = this.audio.createGain();
      o.type = "triangle";
      o.frequency.value = freq;
      g.gain.value = 0.04;
      o.connect(g);
      g.connect(this.audio.destination);
      o.start();
      g.gain.exponentialRampToValueAtTime(0.001, this.audio.currentTime + dur);
      o.stop(this.audio.currentTime + dur);
    } catch {
      /* autoplay may block; ignore */
    }
  }

  private paper(url: string, w: number, h: number) {
    const mat = new THREE.MeshBasicMaterial({
      transparent: true,
      depthWrite: false,
      side: THREE.DoubleSide,
      fog: true,
    });
    new THREE.TextureLoader().load(url, (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      mat.map = t;
      mat.needsUpdate = true;
    });
    return new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
  }

  private pixMat(url: string, repeatX = 1, repeatY = 1) {
    const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, fog: true });
    new THREE.TextureLoader().load(url, (t) => {
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      t.colorSpace = THREE.SRGBColorSpace;
      t.wrapS = THREE.RepeatWrapping;
      t.wrapT = THREE.RepeatWrapping;
      t.repeat.set(repeatX, repeatY);
      mat.map = t;
      mat.needsUpdate = true;
    });
    return mat;
  }

  private facePlane(url: string, pw: number, ph: number, x: number, y: number, z: number, face: "e" | "w" | "s" | "n") {
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(pw, ph), this.pixMat(url));
    const ox = face === "e" ? 0.07 : face === "w" ? -0.07 : 0;
    const oz = face === "s" ? 0.07 : face === "n" ? -0.07 : 0;
    mesh.position.set(x + ox, y, z + oz);
    if (face === "e") mesh.rotation.y = Math.PI / 2;
    if (face === "w") mesh.rotation.y = -Math.PI / 2;
    if (face === "n") mesh.rotation.y = Math.PI;
    this.scene.add(mesh);
  }

  private forgeSword() {
    const g = new THREE.Group();
    const blade = this.paper("/art/sword.png", 0.26, 1.12);
    blade.rotation.x = -Math.PI / 2;
    g.add(blade);
    return g;
  }

  private forgeLute() {
    const g = new THREE.Group();
    const body = this.paper("/art/lute.png", 0.55, 0.48);
    body.rotation.x = -0.35;
    g.add(body);
    return g;
  }

  private forgeBook() {
    const g = new THREE.Group();
    g.add(this.paper("/art/book.png", 0.36, 0.36));
    return g;
  }

  private rigPerson(_tunic: number, _skin: number, guard: boolean, extras?: string) {
    const who = extras ?? "hob";
    const g = new THREE.Group();
    const hips = new THREE.Group();
    hips.position.y = 0.9;
    const torso = new THREE.Group();
    torso.position.y = 0.14;
    const body = this.paper(`/art/doll/${who}_torso.png`, 0.5, 0.52);
    body.position.y = 0.1;
    const head = this.paper(`/art/doll/${who}_head.png`, 0.4, 0.42);
    head.position.y = 0.48;
    torso.add(body, head);
    const mkArm = (side: number, url: string) => {
      const arm = new THREE.Group();
      arm.position.set(0.2 * side, 0.22, 0.03);
      const spr = this.paper(url, 0.16, 0.48);
      spr.position.y = -0.22;
      arm.add(spr);
      return arm;
    };
    const armL = mkArm(-1, `/art/doll/${who}_arm.png`);
    const armR = mkArm(1, `/art/doll/${who}_arm_r.png`);
    torso.add(armL, armR);
    if (guard) {
      const spear = this.paper(`/art/doll/${who}_spear.png`, 0.1, 1.15);
      spear.position.set(0.05, -0.2, 0.05);
      armR.add(spear);
    }
    hips.add(torso);
    const mkLeg = (side: number, url: string) => {
      const leg = new THREE.Group();
      leg.position.set(0.09 * side, 0, 0);
      const spr = this.paper(url, 0.2, 0.54);
      spr.position.y = -0.26;
      leg.add(spr);
      return leg;
    };
    const legL = mkLeg(-1, `/art/doll/${who}_leg.png`);
    const legR = mkLeg(1, `/art/doll/${who}_leg_r.png`);
    hips.add(legL, legR);
    g.add(hips);
    g.userData.limbs = { hips, torso, armL, armR, legL, legR };
    return g;
  }

  private box(
    w: number,
    h: number,
    d: number,
    x: number,
    y: number,
    z: number,
    color: number,
    noClip = false,
    mat?: THREE.Material,
  ) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat ?? this.ps1(color));
    mesh.position.set(x, y, z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    this.scene.add(mesh);
    if (!noClip) {
      this.solids.push({
        min: new THREE.Vector3(x - w / 2, y - h / 2, z - d / 2),
        max: new THREE.Vector3(x + w / 2, y + h / 2, z + d / 2),
      });
    }
    return mesh;
  }

  private torch(x: number, y: number, z: number, c = 0xd4893a, i = 2.4) {
    const light = new THREE.PointLight(c, i, 14, 1.7);
    light.position.set(x, y, z);
    this.scene.add(light);
    const flame = new THREE.Mesh(new THREE.SphereGeometry(0.07, 6, 6), new THREE.MeshBasicMaterial({ color: c }));
    flame.position.copy(light.position);
    this.scene.add(flame);
    this.fires.push({ light, flame, base: i, seed: x * 13 + z });
  }

  private unlitBox(w: number, h: number, d: number, x: number, y: number, z: number, color: number) {
    const m = new THREE.Mesh(
      new THREE.BoxGeometry(w, h, d),
      new THREE.MeshBasicMaterial({ color, fog: true }),
    );
    m.position.set(x, y, z);
    this.scene.add(m);
    return m;
  }

  private postLamp(x: number, z: number, h = 2.55) {
    this.unlitBox(0.11, h, 0.11, x, h / 2, z, 0x8a5a32);
    this.unlitBox(0.08, 0.08, 0.36, x, h - 0.06, z, 0x6e4a28);
    this.unlitBox(0.34, 0.07, 0.34, x, h + 0.3, z, 0x5a3a24);
    this.unlitBox(0.22, 0.04, 0.22, x, h + 0.02, z, 0x4a3220);
    const glass = new THREE.Mesh(
      new THREE.BoxGeometry(0.2, 0.24, 0.2),
      new THREE.MeshBasicMaterial({ color: 0xffd090, fog: true }),
    );
    glass.position.set(x, h + 0.16, z);
    this.scene.add(glass);
    for (const [dx, dz] of [
      [-1, -1],
      [1, -1],
      [-1, 1],
      [1, 1],
    ] as const) {
      this.unlitBox(0.035, 0.26, 0.035, x + dx * 0.11, h + 0.16, z + dz * 0.11, 0x5a4430);
    }
    this.torch(x, h + 0.18, z, 0xffc878, 2.8);
  }

  private wallLamp(x: number, y: number, z: number, face: "e" | "w" | "s" | "n") {
    const ox = face === "e" ? 0.2 : face === "w" ? -0.2 : 0;
    const oz = face === "s" ? 0.2 : face === "n" ? -0.2 : 0;
    this.unlitBox(0.08, 0.08, 0.26, x + ox * 0.35, y, z + oz * 0.35, 0x8a5a32);
    const gx = x + ox;
    const gz = z + oz;
    this.unlitBox(0.28, 0.06, 0.28, gx, y + 0.16, gz, 0x5a3a24);
    const glass = new THREE.Mesh(
      new THREE.BoxGeometry(0.16, 0.18, 0.16),
      new THREE.MeshBasicMaterial({ color: 0xffd090, fog: true }),
    );
    glass.position.set(gx, y, gz);
    this.scene.add(glass);
    this.torch(gx, y, gz, 0xffc878, 2.2);
  }

  private wallTorch(x: number, y: number, z: number, face: "e" | "w" | "s" | "n") {
    const ox = face === "e" ? 0.16 : face === "w" ? -0.16 : 0;
    const oz = face === "s" ? 0.16 : face === "n" ? -0.16 : 0;
    this.box(0.05, 0.05, 0.28, x + ox * 0.5, y, z + oz * 0.5, 0x2a241c, true);
    this.box(0.06, 0.34, 0.06, x + ox, y + 0.08, z + oz, 0x3a2414, true);
    this.torch(x + ox, y + 0.28, z + oz, 0xff8a32, 2.0);
  }

  private lantern(x: number, y: number, z: number) {
    this.postLamp(x, z, y);
  }

  private firepit(x: number, z: number, big = false) {
    const s = big ? 1.15 : 0.85;
    this.box(1.1 * s, 0.18, 1.1 * s, x, 0.1, z, 0x2a241c, true);
    this.box(0.7 * s, 0.12, 0.22, x, 0.2, z, 0x3a2414, true);
    this.box(0.22, 0.12, 0.7 * s, x, 0.22, z + 0.05, 0x2e1c10, true);
    const h = big ? 3.4 : 2.4;
    const flame = new THREE.Mesh(
      new THREE.ConeGeometry(0.22 * s, 0.7 * s, 5),
      new THREE.MeshBasicMaterial({ color: 0xffaa44 }),
    );
    flame.position.set(x, 0.55 * s, z);
    this.scene.add(flame);
    const glow = new THREE.Mesh(
      new THREE.SphereGeometry(0.16 * s, 6, 6),
      new THREE.MeshBasicMaterial({ color: 0xffcc66 }),
    );
    glow.position.set(x, 0.38 * s, z);
    this.scene.add(glow);
    const light = new THREE.PointLight(0xff8a32, h, 16, 1.55);
    light.position.set(x, 1.05, z);
    this.scene.add(light);
    this.fires.push({ light, flame, base: h, seed: x * 7 + z });
  }

  private pane(x: number, y: number, z: number, face: "e" | "w" | "s" | "n") {
    const ox = face === "e" ? 0.04 : face === "w" ? -0.04 : 0;
    const oz = face === "s" ? 0.04 : face === "n" ? -0.04 : 0;
    const w = face === "e" || face === "w" ? 0.06 : 0.46;
    const d = face === "e" || face === "w" ? 0.46 : 0.06;
    this.box(w, 0.62, d, x + ox, y, z + oz, 0x1a120c, true);
    const glass = new THREE.Mesh(
      new THREE.BoxGeometry(Math.max(0.04, w - 0.02), 0.48, Math.max(0.04, d - 0.02)),
      new THREE.MeshBasicMaterial({ color: 0xffc070 }),
    );
    glass.position.set(x + ox * 1.4, y, z + oz * 1.4);
    this.scene.add(glass);
  }

  private house(
    x: number,
    z: number,
    w: number,
    h: number,
    d: number,
    name: string,
    opts: { stone?: boolean; face?: "e" | "w" | "s" | "n"; art?: string } = {},
  ) {
    const stone = !!opts.stone;
    const face = opts.face ?? "s";
    const mat = stone ? this.stoneMat : this.woodMat;
    const col = stone ? 0x5a4236 : 0x4a3428;
    this.box(w, h, d, x, h / 2, z, col, false, mat);
    const roofMat = this.pixMat("/art/buildings/roof.png", 3, 2);
    this.box(w + 0.9, 0.22, d + 0.7, x, h + 0.08, z, 0x3a2016, false, roofMat);
    const slope = this.box(w + 0.7, 0.16, d * 0.62, x, h + 0.55, z, 0x4a2818, true, roofMat);
    slope.rotation.x = 0.38;
    this.box(0.55, 1.15, 0.55, x + w * 0.28, h + 0.7, z - d * 0.22, 0x3a2a22, true);
    this.box(0.38, 0.28, 0.38, x + w * 0.28, h + 1.35, z - d * 0.22, 0x2a1c16, true);
    const fx = face === "e" ? x + w / 2 : face === "w" ? x - w / 2 : x;
    const fz = face === "s" ? z + d / 2 : face === "n" ? z - d / 2 : z;
    const frontW = face === "e" || face === "w" ? d : w;
    if (opts.art) {
      this.facePlane(`/art/buildings/${opts.art}.png`, frontW * 0.98, h * 0.98, fx, h / 2, fz, face);
    } else {
      const doorW = face === "e" || face === "w" ? 0.16 : 1.15;
      const doorD = face === "e" || face === "w" ? 1.15 : 0.16;
      this.box(doorW, 2.05, doorD, fx, 1.02, fz, 0x1a1210);
      const along = frontW;
      const nWin = Math.max(2, Math.round(along / 3.2));
      for (let i = 0; i < nWin; i++) {
        const t = (i + 0.7) / (nWin + 0.4) - 0.5;
        if (Math.abs(t) < 0.12) continue;
        const wx = face === "e" || face === "w" ? fx : x + t * w * 0.72;
        const wz = face === "e" || face === "w" ? z + t * d * 0.72 : fz;
        this.pane(wx, 1.7, wz, face);
      }
    }
    this.sign(fx, h + 0.28, fz, name, face);
    if (face === "e" || face === "w") {
      this.wallLamp(fx, 2.2, z - Math.min(1.35, d * 0.28), face);
      this.wallLamp(fx, 2.2, z + Math.min(1.35, d * 0.28), face);
    } else {
      this.wallLamp(x - Math.min(1.35, w * 0.28), 2.2, fz, face);
      this.wallLamp(x + Math.min(1.35, w * 0.28), 2.2, fz, face);
    }
  }

  private shop(x: number, z: number, w: number, h: number, d: number, name: string, stone = false) {
    this.house(x, z, w, h, d, name, { stone, face: "s" });
  }

  private placeHaunted(proto: THREE.Object3D, x: number, z: number, targetH: number) {
    const g = proto.clone();
    g.position.set(0, 0, 0);
    g.rotation.set(0, 0, 0);
    g.scale.set(1, 1, 1);
    g.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(g);
    const h = Math.max(0.05, box.max.y - box.min.y);
    const s = targetH / h;
    const cx = (box.min.x + box.max.x) * 0.5;
    const cz = (box.min.z + box.max.z) * 0.5;
    g.scale.setScalar(s);
    g.position.set(x - cx * s, -box.min.y * s, z - cz * s);
    g.rotation.y = (x * 12.9898 + z * 78.233) % (Math.PI * 2);
    this.scene.add(g);
    const r = Math.min(1.2, targetH * 0.08);
    this.solids.push({
      min: new THREE.Vector3(x - r, 0, z - r),
      max: new THREE.Vector3(x + r, targetH, z + r),
    });
  }

  private tree(x: number, z: number, kind: "pine" | "dead" | "bush" = "pine") {
    if (kind === "bush") {
      const list = this.hauntedBushes;
      if (list.length) {
        this.placeHaunted(list[Math.abs(Math.floor(x * 10)) % list.length], x, z, 1.6 + (Math.abs(z) % 1));
        return;
      }
      const n = 1 + Math.floor(Math.abs(x * 10) % 5);
      this.psxCard(`/models/psx-nature/bush_0${n}.png`, x, z, 2.4, 1.8);
      return;
    }
    const list = this.hauntedTrees;
    if (list.length) {
      const i = Math.abs(Math.floor(z * 8)) % list.length;
      const tall = kind === "pine" ? 12 : 9;
      this.placeHaunted(list[i], x, z, tall + (Math.abs(x) % 3));
      return;
    }
    const n = 1 + Math.floor(Math.abs(z * 8) % 8);
    this.psxCard(`/models/psx-nature/tree0${n}.png`, x, z, 7.5, 11);
    this.solids.push({
      min: new THREE.Vector3(x - 0.55, 0, z - 0.55),
      max: new THREE.Vector3(x + 0.55, 8, z + 0.55),
    });
  }

  private forestBlocked(x: number, z: number, r = 0) {
    const onStreet = z > -22 && z < 32;
    if (onStreet && Math.abs(x) < 5.2 + r) return true;
    for (const b of HOUSES) {
      if (Math.abs(x - b.x) < b.w * 0.5 + r && Math.abs(z - b.z) < b.d * 0.5 + r) return true;
    }
    if (z < -19.2 + r && Math.abs(x) < 40) return true;
    if (Math.hypot(x, z - 28) < 5 + r * 0.35) return true;
    return false;
  }

  private plantForest() {
    this.plantGrassGround();
    let s = 1337;
    const rnd = () => {
      s = (s * 16807) % 2147483647;
      return (s - 1) / 2147483646;
    };
    const placed: [number, number, number][] = [];
    const pick = (): "pine" | "dead" | "bush" => {
      const r = rnd();
      if (r < 0.18) return "bush";
      if (r < 0.38) return "dead";
      return "pine";
    };
    const occ = new Set<string>();
    const cellOf = (x: number, z: number, s: number) => `${Math.round(x / s)},${Math.round(z / s)}`;
    const inTown = (x: number, z: number) => Math.abs(x) < 15.5 && z > -16.5 && z < 25.8;
    for (let i = 0; i < 12000 && placed.length < 1400; i++) {
      const x = (rnd() - 0.5) * 152;
      const z = (rnd() - 0.5) * 140 + 6;
      const kind = pick();
      if (inTown(x, z) && kind !== "bush") continue;
      const rad = kind === "bush" ? 1.05 : kind === "dead" ? 6.2 : 8.0;
      if (this.forestBlocked(x, z, rad)) continue;
      const min = kind === "bush" ? 2.4 : 4.2;
      const k = cellOf(x, z, min * 0.65);
      if (occ.has(k)) continue;
      occ.add(k);
      this.tree(x, z, kind);
      placed.push([x, z, min]);
    }
    for (const b of HOUSES) {
      if (Math.abs(b.x) < 5) continue;
      const toward = b.x < 0 ? -1 : 1;
      for (const oz of [-b.d * 0.28, b.d * 0.28]) {
        const x = b.x + toward * (b.w * 0.5 + 1.15);
        const z = b.z + oz;
        if (this.forestBlocked(x, z, 0.95)) continue;
        this.tree(x, z, "bush");
      }
    }
    for (let i = 0; i < 80; i++) {
      const x = (rnd() - 0.5) * 110;
      const z = (rnd() - 0.5) * 100 + 4;
      if (this.forestBlocked(x, z, 0.9)) continue;
      if (placed.some(([px, pz]) => (px - x) ** 2 + (pz - z) ** 2 < 6)) continue;
      this.rock(x, z, 0.75 + rnd() * 0.55);
    }
    for (let i = 0; i < 1600; i++) {
      const x = (rnd() - 0.5) * 96;
      const z = (rnd() - 0.5) * 88 + 4;
      if (Math.abs(x) < 2.2 && z > -18 && z < 30) continue;
      if (Math.hypot(x, z - 28) < 3.8) continue;
      const mat = this.grassMats[Math.floor(rnd() * this.grassMats.length)];
      if (!mat) continue;
      const w = 1.2 + rnd() * 0.9;
      const h = 0.6 + rnd() * 0.45;
      const geo = new THREE.PlaneGeometry(w, h);
      const a = new THREE.Mesh(geo, mat);
      const b = new THREE.Mesh(geo, mat);
      b.rotation.y = Math.PI / 2;
      const g = new THREE.Group();
      g.add(a, b);
      g.position.set(x, h * 0.48, z);
      g.rotation.y = rnd() * Math.PI * 2;
      this.scene.add(g);
    }
  }

  private plantGrassGround() {
    const grass = this.tileMat("/models/psx-nature/grass_tile.png", 2.2, 0xc4d4a4);
    const moss = this.tileMat("/models/psx-nature/moss_tile.png", 2.0, 0xb8c898);
    const mix = this.tileMat("/models/psx-nature/dirt_grass.png", 2.4, 0xc8b898);
    const blocked = (x: number, z: number) => {
      if (Math.abs(x) < 2.15 && z > -19 && z < 31) return true;
      if (z < -19 && Math.abs(x) < 38) return true;
      if (Math.hypot(x, z - 28) < 3.6) return true;
      return false;
    };
    for (let gx = -76; gx <= 76; gx += 8) {
      for (let gz = -70; gz <= 76; gz += 8) {
        if (blocked(gx, gz)) continue;
        const mat = (gx * 13 + gz * 7) % 5 === 0 ? moss : grass;
        this.grassPatch(gx, gz, 9.4, 9.4, mat);
      }
    }
    for (let gz = -16; gz <= 26; gz += 2.4) {
      for (const side of [-1, 1]) {
        this.grassPatch(side * 2.55, gz, 1.35, 2.8, mix, 0.02);
        this.grassPatch(side * 3.35, gz, 1.5, 2.8, grass, 0.021);
      }
    }
    for (const lot of [-9.2, 9.2]) {
      for (const z of [21.5, 14.2, 6.4, -2.2, -11.6]) {
        this.grassPatch(lot * 0.52, z, 4.8, 6.2, grass);
      }
    }
  }

  private rock(x: number, z: number, s = 1) {
    const spr = this.bitSprite("/art/rock.png", 1.35 * s, 1.05 * s, 0.42 * s);
    spr.position.x = x;
    spr.position.z = z;
    this.scene.add(spr);
    this.solids.push({
      min: new THREE.Vector3(x - 0.4 * s, 0, z - 0.4 * s),
      max: new THREE.Vector3(x + 0.4 * s, 0.8 * s, z + 0.4 * s),
    });
  }

  private sign(x: number, y: number, z: number, text: string, face: "e" | "w" | "s" | "n" = "s") {
    const c = document.createElement("canvas");
    c.width = 256;
    c.height = 96;
    const g = c.getContext("2d")!;
    g.fillStyle = "#3a2418";
    g.fillRect(0, 0, 256, 96);
    g.strokeStyle = "#8a6a32";
    g.lineWidth = 6;
    g.strokeRect(4, 4, 248, 88);
    g.fillStyle = "#e8d7b8";
    g.font = "700 22px 'Cormorant Garamond', Georgia, serif";
    g.textAlign = "center";
    g.fillText(text, 128, 56);
    const tex = new THREE.CanvasTexture(c);
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestFilter;
    const board = new THREE.Mesh(
      new THREE.PlaneGeometry(1.7, 0.64),
      new THREE.MeshStandardMaterial({ map: tex, roughness: 1 }),
    );
    const ox = face === "e" ? 0.14 : face === "w" ? -0.14 : 0;
    const oz = face === "s" ? 0.14 : face === "n" ? -0.14 : 0;
    board.position.set(x + ox, y, z + oz);
    if (face === "e") board.rotation.y = Math.PI / 2;
    if (face === "w") board.rotation.y = -Math.PI / 2;
    if (face === "n") board.rotation.y = Math.PI;
    this.scene.add(board);
  }

  private label(text: string) {
    const c = document.createElement("canvas");
    c.width = 256;
    c.height = 64;
    const g = c.getContext("2d")!;
    g.fillStyle = "rgba(12,8,6,0.7)";
    g.fillRect(0, 0, 256, 64);
    g.fillStyle = "#e8d7b8";
    g.font = "600 28px 'Cormorant Garamond', Georgia, serif";
    g.textAlign = "center";
    g.fillText(text, 128, 42);
    const tex = new THREE.CanvasTexture(c);
    const spr = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false }));
    spr.scale.set(1.6, 0.4, 1);
    return spr;
  }

  private addNpc(cfg: {
    id: string;
    name: string;
    color: number;
    x: number;
    z: number;
    rot?: number;
    skin?: number;
    lines: string[];
    purse?: number;
    guard?: boolean;
    hp?: number;
  }) {
    const g = this.rigPerson(cfg.color, cfg.skin ?? 0xb08a62, !!cfg.guard, cfg.id);
    const lab = this.label(cfg.name);
    lab.position.y = 1.95;
    g.add(lab);
    g.position.set(cfg.x, 0, cfg.z);
    g.rotation.y = cfg.rot ?? 0;
    g.userData.home = new THREE.Vector3(cfg.x, 0, cfg.z);
    g.userData.target = new THREE.Vector3(cfg.x, 0, cfg.z);
    g.userData.lab = lab;
    this.scene.add(g);
    this.npcs.push({
      id: cfg.id,
      name: cfg.name,
      color: cfg.color,
      skin: cfg.skin ?? 0xc4a07a,
      mesh: g,
      hp: cfg.hp ?? 40,
      purse: cfg.purse ?? 3,
      hostile: false,
      hitCd: 0,
      wanderT: Math.random() * 4,
      picked: false,
      charmed: false,
      guard: !!cfg.guard,
      ally: false,
      lines: cfg.lines,
      kind: "person",
      sitT: 0,
    });
  }

  private addCritter(id: string, name: string, art: "squirrel" | "rat", x: number, z: number) {
    const g = new THREE.Group();
    const w = art === "squirrel" ? 0.48 : 0.55;
    const h = art === "squirrel" ? 0.48 : 0.32;
    const s = this.bitSprite(`/art/${art}.png`, w, h, h * 0.5);
    g.add(s);
    g.position.set(x, 0, z);
    g.userData.home = new THREE.Vector3(x, 0, z);
    g.userData.target = new THREE.Vector3(x, 0, z);
    this.scene.add(g);
    this.npcs.push({
      id,
      name,
      color: 0x4a3a28,
      skin: 0xb08a62,
      mesh: g,
      hp: 8,
      purse: 0,
      hostile: false,
      hitCd: 0,
      wanderT: Math.random() * 2,
      picked: false,
      charmed: false,
      guard: false,
      ally: false,
      lines: [],
      kind: "critter",
      sitT: 0,
    });
  }

  private addHound(x: number, z: number) {
    const g = new THREE.Group();
    const sit = this.paper("/art/hound-sit.png", 1.2, 1.2);
    sit.position.y = 0.55;
    const walk = this.paper("/art/hound-walk.png", 1.4, 0.82);
    walk.position.y = 0.4;
    walk.visible = false;
    g.add(sit, walk);
    const lab = this.label("Bramble");
    lab.position.y = 1.35;
    g.add(lab);
    g.position.set(x, 0, z);
    g.userData.home = new THREE.Vector3(x, 0, z);
    g.userData.target = new THREE.Vector3(x, 0, z);
    g.userData.lab = lab;
    g.userData.sitSpr = sit;
    g.userData.walkSpr = walk;
    this.scene.add(g);
    this.npcs.push({
      id: "bramble",
      name: "Bramble",
      color: 0x6a4428,
      skin: 0xc4a07a,
      mesh: g,
      hp: 40,
      purse: 0,
      hostile: false,
      hitCd: 0,
      wanderT: 2,
      picked: false,
      charmed: false,
      guard: false,
      ally: false,
      lines: ["..."],
      kind: "hound",
      sitT: 3,
    });
  }

  private buildWorld() {
    this.hemi = new THREE.HemisphereLight(0x4a5460, 0x1a120c, 0.42);
    this.scene.add(this.hemi);
    this.sun = new THREE.DirectionalLight(0x8890a0, 0.18);
    this.sun.position.set(-20, 30, 10);
    this.scene.add(this.sun);
    this.buildSky();
    this.applyTime();

    const ground = new THREE.Mesh(new THREE.PlaneGeometry(160, 160), this.mudMat);
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    this.scene.add(ground);

    this.cobblePath();

    this.house(-9.2, 21.5, 7.2, 4.1, 6.2, "MUD HOUSE", { face: "e", art: "cottage" });
    this.house(-9.2, 14.2, 7.2, 4.4, 6.4, "NO BEDS", { face: "e", art: "hostel" });
    this.house(-9.4, 6.4, 7.8, 5.0, 7.2, "IRON & ASH", { stone: true, face: "e", art: "smith" });
    this.house(-9.6, -2.2, 8.2, 6.4, 7.6, "ST. DRIP", { stone: true, face: "e", art: "chapel" });
    this.house(-9.0, -11.6, 6.8, 4.0, 5.6, "LEAN-TO", { face: "e", art: "cottage" });

    this.house(9.2, 21.5, 7.2, 4.0, 6.2, "COOPER", { face: "w", art: "shop" });
    this.house(9.2, 14.2, 7.2, 4.2, 6.4, "HIDE WORKS", { face: "w", art: "shop" });
    this.house(9.6, 6.2, 8.4, 6.2, 8.4, "THE GENEROUS CUP", { face: "w", art: "inn" });
    this.house(9.4, -3.4, 8.0, 4.3, 7.4, "THE KING'S NAGS", { face: "w", art: "stables" });
    this.house(8.8, -12.0, 6.6, 3.9, 5.4, "TALLOW", { face: "w", art: "shop" });

    this.box(2.6, 2.4, 2.2, -3.6, 1.2, 4.2, 0x4a3a2c, false, this.woodMat);
    this.box(2.8, 0.18, 1.4, -3.6, 2.5, 4.2, 0x2a1810, true);
    this.sign(-2.3, 2.35, 4.2, "ROAD TAX", "e");
    this.wallLamp(-2.25, 1.85, 4.2, "e");

    this.postLamp(-2.35, 22.2);
    this.postLamp(2.35, 22.2);
    this.postLamp(-2.35, 14.4);
    this.postLamp(2.35, 14.4);
    this.postLamp(-2.35, 7.6);
    this.postLamp(2.35, 7.6);
    this.postLamp(-2.35, -0.4);
    this.postLamp(2.35, -0.4);
    this.postLamp(-2.35, -16.2);
    this.postLamp(2.35, -16.2);

    this.firepit(-5.4, 10.2, true);
    this.firepit(5.6, 10.6);
    this.firepit(-8.2, -16.6);
    this.firepit(8.2, -16.6);

    this.box(4, 2, 4, -22, 1, 8, 0x3a3a38);
    this.box(3, 1.4, 3, 24, 0.7, 16, 0x333230);

    this.addNpc({
      id: "hob",
      name: "Hob",
      color: 0x4a3a28,
      x: 1.6,
      z: 5.2,
      rot: 0.4,
      purse: 6,
      lines: [
        "Road tax. Feast night. Double, unless you're expected.",
        "If anyone asks, you were a priest. I'm a businessman.",
        "The gate's for guests. The ditch is for poets.",
      ],
    });
    this.addNpc({
      id: "marta",
      name: "Marta",
      color: 0x6a2a28,
      x: 4.8,
      z: 6.2,
      rot: -1.2,
      purse: 4,
      lines: [
        "They named this cup after him. The ale tastes like a policy.",
        "East gallery, first course. That's where he parks what he stole.",
        "Sister Pell brings her water. Pell hates a tax more than a sermon.",
      ],
    });
    this.addNpc({
      id: "bren",
      name: "Guard Bren",
      color: 0x3a4450,
      x: -5.5,
      z: -17.5,
      guard: true,
      hp: 55,
      purse: 2,
      lines: [
        "Kitchen door unlatches at the second bell. That's not a gift. That's a complaint.",
        "Keep that iron in its hole. Feast night is noisy enough.",
      ],
    });
    this.addNpc({
      id: "cole",
      name: "Guard Cole",
      color: 0x3a4450,
      x: 5.5,
      z: -17.5,
      guard: true,
      hp: 55,
      purse: 2,
      lines: [
        "Cousin of a baron, are you? They all are, tonight.",
        "The swan is already burnt. His Generous Majesty will not notice.",
      ],
    });
    this.addNpc({
      id: "pell",
      name: "Sister Pell",
      color: 0x2a2a38,
      x: -5.2,
      z: -2.2,
      rot: 1.1,
      skin: 0xb8946c,
      purse: 1,
      lines: [
        "I keep a key because I do not trust doors that belong to kings.",
        "Mara Venn has a spine. Try not to rescue her like furniture.",
        "If you use the old words near the moat, something listens.",
      ],
    });
    this.addNpc({
      id: "ralf",
      name: "Drunk Ralf",
      color: 0x4a4a28,
      x: 4.2,
      z: 11.4,
      rot: 2,
      purse: 5,
      lines: [
        "I am Cousin Ralf of the eastern orchards. Ask anyone. Don't.",
        "If you need a name at the gate, mine is already ruined. Be my guest.",
      ],
    });
    this.addHound(4.8, 9.4);
    this.addCritter("sq1", "Squirrel", "squirrel", -14.5, 19);
    this.addCritter("sq2", "Squirrel", "squirrel", 15.2, 12);
    this.addCritter("sq3", "Squirrel", "squirrel", -16.8, -6);
    this.addCritter("sq4", "Squirrel", "squirrel", 12.4, 24);
    this.addCritter("rat1", "Rat", "rat", 6.2, 8.4);
    this.addCritter("rat2", "Rat", "rat", -3.2, 5.8);
    this.addCritter("rat3", "Rat", "rat", 1.4, 24.6);
    this.addCritter("rat4", "Rat", "rat", 8.8, -2.2);
  }

  private buildDitch() {
    const cx = DITCH.x;
    const cz = DITCH.z - 1.1;
    const geo = new THREE.PlaneGeometry(16, 16, 16, 16);
    geo.rotateX(-Math.PI / 2);
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);
      const r = Math.hypot(x, z);
      const wobble = 0.55 * Math.sin(x * 0.9) * Math.cos(z * 0.7);
      const rr = r + wobble;
      let y = 0.012;
      if (rr < 7.2) {
        const t = 1 - rr / 7.2;
        y = 0.012 - 0.38 * t * t * (0.85 + 0.15 * Math.sin(x * 2.2 + z));
      }
      pos.setY(i, y);
    }
    pos.needsUpdate = true;
    geo.computeVertexNormals();
    const bowl = new THREE.Mesh(geo, this.tileMat("/models/psx-nature/dirt_grass.png", 6, 0xc8b090));
    bowl.position.set(cx, 0, cz);
    this.scene.add(bowl);

    const bed = new THREE.Mesh(
      new THREE.CircleGeometry(3.1, 12),
      this.tileMat("/art/mud.png", 3, 0x8a6a48),
    );
    bed.rotation.x = -Math.PI / 2;
    bed.position.set(cx, -0.22, cz);
    this.scene.add(bed);

    for (const [x, z, s] of [
      [-0.8, 0.4, 1.1],
      [1.2, -0.6, 0.85],
      [0.1, 1.3, 0.7],
    ] as const) {
      const puddle = new THREE.Mesh(
        new THREE.CircleGeometry(s, 8),
        new THREE.MeshBasicMaterial({ color: 0x3a3228, fog: true }),
      );
      puddle.rotation.x = -Math.PI / 2;
      puddle.position.set(cx + x, -0.205, cz + z);
      this.scene.add(puddle);
    }

    this.box(1.1, 0.18, 0.18, -2.6, 0.12, 30.2, 0x3a2a1c, true);
    this.box(0.18, 0.7, 0.18, -2.9, 0.35, 30.4, 0x2a1c14, true);
    this.box(0.9, 0.08, 0.9, 3.2, 0.06, 26.8, 0x2e2418, true);

    for (const [x, z] of [
      [-3.4, 26.2],
      [3.6, 29.5],
      [-4.1, 31],
      [4.4, 27.1],
      [-2.2, 25.4],
      [2.8, 31.6],
    ]) {
      const reed = new THREE.Mesh(
        new THREE.CylinderGeometry(0.03, 0.05, 1.15, 4),
        new THREE.MeshBasicMaterial({ color: 0x4a6a32, fog: true }),
      );
      reed.position.set(x, 0.55, z);
      reed.rotation.z = (x > 0 ? -1 : 1) * 0.12;
      this.scene.add(reed);
    }

    this.firepit(0.2, 27.4);
    this.postLamp(-2.6, 26.4, 2.2);
    this.postLamp(2.6, 26.4, 2.2);

    this.buildFairy();
    this.buildGifts();
  }

  private buildFairy() {
    const g = new THREE.Group();
    const body = new THREE.Mesh(
      new THREE.SphereGeometry(0.11, 8, 8),
      new THREE.MeshStandardMaterial({
        color: 0xc9d4a8,
        emissive: 0x3a4a22,
        emissiveIntensity: 0.7,
        roughness: 0.45,
      }),
    );
    const dress = new THREE.Mesh(
      new THREE.ConeGeometry(0.15, 0.3, 6),
      new THREE.MeshStandardMaterial({ color: 0x3a4a2a, roughness: 0.85 }),
    );
    dress.position.y = -0.16;
    const wingGeo = new THREE.PlaneGeometry(0.26, 0.16);
    const wingMat = new THREE.MeshStandardMaterial({
      color: 0xdce8c8,
      transparent: true,
      opacity: 0.55,
      side: THREE.DoubleSide,
      emissive: 0x88aa55,
      emissiveIntensity: 0.35,
    });
    const wingL = new THREE.Mesh(wingGeo, wingMat);
    const wingR = new THREE.Mesh(wingGeo, wingMat);
    wingL.position.set(-0.14, 0.02, 0.02);
    wingR.position.set(0.14, 0.02, 0.02);
    const light = new THREE.PointLight(0xb8d080, 3.2, 14, 1.6);
    light.position.y = 0.08;
    const spr = new THREE.Sprite(this.nixMat);
    spr.scale.set(1.05, 1.78, 1);
    spr.position.y = 0.15;
    const lab = this.label("Nix");
    lab.position.y = 1.05;
    lab.scale.set(1.2, 0.3, 1);
    g.add(body, dress, wingL, wingR, light, spr, lab);
    g.position.set(2.6, 3.6, 23.6);
    this.scene.add(g);
    this.fairy = { mesh: g, wings: [wingL, wingR], t: 0, gone: false };
  }

  private buildGifts() {
    const sword = new THREE.Group();
    const steel = this.paper("/art/sword.png", 0.38, 1.5);
    steel.position.y = 0.78;
    sword.add(steel);
    sword.position.set(-1.7, 0.02, 25.4);
    const swordGlow = new THREE.PointLight(0x6a7080, 0.9, 5);
    sword.add(swordGlow);
    const swordLab = this.label("Sword");
    swordLab.position.set(0, 1.15, 0);
    sword.add(swordLab);
    this.scene.add(sword);
    this.gifts.push({ id: "steel", mesh: sword, hint: "E — take the sword. Fight the party." });

    const lute = new THREE.Group();
    lute.add(this.forgeLute());
    lute.position.set(0.05, 0.18, 24.6);
    lute.rotation.y = 0.5;
    const luteGlow = new THREE.PointLight(0x8a6a32, 0.9, 5);
    lute.add(luteGlow);
    const luteLab = this.label("Lute");
    luteLab.position.set(0, 0.7, 0);
    lute.add(luteLab);
    this.scene.add(lute);
    this.gifts.push({ id: "song", mesh: lute, hint: "E — take the lute. Get invited." });

    const tome = new THREE.Group();
    tome.add(this.forgeBook());
    tome.position.set(1.75, 0.12, 25.5);
    tome.rotation.y = -0.4;
    const bookGlow = new THREE.PointLight(0xa05028, 1.2, 5.5);
    tome.add(bookGlow);
    const bookLab = this.label("Spellbook");
    bookLab.position.set(0, 0.45, 0);
    tome.add(bookLab);
    this.scene.add(tome);
    this.gifts.push({ id: "spark", mesh: tome, hint: "E — take the book. Blast the hall." });
  }

  private buildViewmodels() {
    this.sword.add(this.forgeSword());
    this.sword.position.set(0.42, -0.34, -0.6);
    this.sword.rotation.set(-0.12, 0.35, -0.18);
    this.sword.visible = false;
    this.camera.add(this.sword);

    this.lute.add(this.forgeLute());
    this.lute.position.set(0.32, -0.24, -0.5);
    this.lute.rotation.set(0.35, 0.7, -0.25);
    this.lute.visible = false;
    this.camera.add(this.lute);

    this.book.add(this.forgeBook());
    this.book.position.set(0.3, -0.22, -0.48);
    this.book.rotation.set(0.5, 0.4, -0.15);
    this.book.visible = false;
    this.camera.add(this.book);
  }

  private equip(id: PathId) {
    this.sword.visible = id === "steel";
    this.lute.visible = id === "song";
    this.book.visible = id === "spark";
  }

  private dismissGifts() {
    for (const g of this.gifts) {
      g.mesh.visible = false;
      this.scene.remove(g.mesh);
    }
  }

  private dismissFairy(line: string) {
    this.fairyTalk = line;
    this.log(line);
    if (this.fairy) this.fairy.gone = true;
  }

  private takeGift(id: Exclude<PathId, "none" | "feather">) {
    if (this.path !== "none") return;
    this.path = id;
    this.phase = "play";
    this.equip(id);
    this.dismissGifts();
    this.player.spark = id === "spark" ? 6 : 0;
    if (id === "steel") {
      this.player.steel += 1;
      this.dismissFairy("Nix: 'Try not to die in the first sentence.'");
      this.tone(180, 0.14);
    } else if (id === "song") {
      this.player.tongue += 1;
      this.dismissFairy("Nix: 'Smile when you lie. It's cheaper than a seal.'");
      this.tone(330, 0.16);
    } else {
      this.player.sparkStat += 1;
      this.dismissFairy("Nix: 'The words are old. His drapes are not fireproof. Coincidence.'");
      this.tone(520, 0.18);
    }
    window.setTimeout(() => {
      if (this.fairyTalk?.startsWith("Nix:")) this.fairyTalk = null;
      this.emit();
    }, 4200);
    this.emit();
  }

  private takeFeather() {
    if (this.path !== "none" || !this.fairy || this.fairy.gone) return;
    this.path = "feather";
    this.phase = "play";
    this.equip("feather");
    this.dismissGifts();
    this.player.shadow += 2;
    this.player.coin += 9;
    this.tone(90, 0.22);
    this.dismissFairy("Nix: 'FEATHER HANDS. Fine. Rob the county. I'm leaving before you nick the wings.'");
    window.setTimeout(() => {
      if (this.fairyTalk?.startsWith("Nix:")) this.fairyTalk = null;
      this.emit();
    }, 4800);
    this.emit();
  }

  private onKeyDown = (e: KeyboardEvent) => {
    this.keys.add(e.code);
    if (["Space", "KeyF", "KeyE", "KeyQ"].includes(e.code)) e.preventDefault();
    if (this.phase === "boot") return;
    if (e.code === "KeyE") this.doTalk();
    if (e.code === "KeyF") this.doPocket();
    if (e.code === "KeyQ") this.cast();
    if (e.code.startsWith("Digit")) {
      const i = Number(e.code.slice(5)) - 1;
      this.pickChoice(i);
    }
    if (e.code.startsWith("Numpad") && e.code.length === 7) {
      const i = Number(e.code.slice(6)) - 1;
      this.pickChoice(i);
    }
  };
  private onKeyUp = (e: KeyboardEvent) => {
    this.keys.delete(e.code);
  };
  private onBlur = () => {
    this.keys.clear();
  };
  private onMouseMove = (e: MouseEvent) => {
    if (!this.locked || this.phase === "wake" || this.phase === "boot") return;
    this.yaw -= e.movementX * 0.0022;
    this.pitch -= e.movementY * 0.0022;
    const lim = Math.PI / 2 - 0.01;
    this.pitch = Math.max(-lim, Math.min(lim, this.pitch));
  };
  private onMouseDown = (e: MouseEvent) => {
    if (!this.locked) return;
    if (e.button !== 0) return;
    if (this.path === "steel") this.swing();
    else if (this.path === "spark") this.cast();
    else if (this.path === "song") this.playTune();
    else if (this.phase === "gift") this.doTalk();
  };
  private onLock = () => {
    this.locked = document.pointerLockElement === this.canvas;
    if (this.locked) this.hadLock = true;
    this.emit();
  };
  private onResize = () => this.resize();

  private bind() {
    addEventListener("keydown", this.onKeyDown);
    addEventListener("keyup", this.onKeyUp);
    addEventListener("blur", this.onBlur);
    addEventListener("mousemove", this.onMouseMove);
    this.canvas.addEventListener("mousedown", this.onMouseDown);
    document.addEventListener("pointerlockchange", this.onLock);
    addEventListener("resize", this.onResize);
    this.canvas.addEventListener("touchstart", this.onTouchStart, { passive: false });
    this.canvas.addEventListener("touchmove", this.onTouchMove, { passive: false });
    this.canvas.addEventListener("touchend", this.onTouchEnd);
  }

  private unbind() {
    removeEventListener("keydown", this.onKeyDown);
    removeEventListener("keyup", this.onKeyUp);
    removeEventListener("blur", this.onBlur);
    removeEventListener("mousemove", this.onMouseMove);
    this.canvas.removeEventListener("mousedown", this.onMouseDown);
    document.removeEventListener("pointerlockchange", this.onLock);
    removeEventListener("resize", this.onResize);
    this.canvas.removeEventListener("touchstart", this.onTouchStart);
    this.canvas.removeEventListener("touchmove", this.onTouchMove);
    this.canvas.removeEventListener("touchend", this.onTouchEnd);
  }

  private onTouchStart = (e: TouchEvent) => {
    e.preventDefault();
    for (const t of Array.from(e.changedTouches)) {
      if (t.clientX < innerWidth * 0.45) {
        this.stick = { id: t.identifier, x: t.clientX, y: t.clientY, dx: 0, dy: 0 };
      } else {
        this.lookTouch = { id: t.identifier, x: t.clientX, y: t.clientY };
      }
    }
  };
  private onTouchMove = (e: TouchEvent) => {
    e.preventDefault();
    for (const t of Array.from(e.changedTouches)) {
      if (this.stick && t.identifier === this.stick.id) {
        this.stick.dx = (t.clientX - this.stick.x) / 60;
        this.stick.dy = (t.clientY - this.stick.y) / 60;
      }
      if (this.lookTouch && t.identifier === this.lookTouch.id) {
        this.yaw -= (t.clientX - this.lookTouch.x) * 0.006;
        this.pitch -= (t.clientY - this.lookTouch.y) * 0.006;
        const lim = Math.PI / 2 - 0.01;
        this.pitch = Math.max(-lim, Math.min(lim, this.pitch));
        this.lookTouch.x = t.clientX;
        this.lookTouch.y = t.clientY;
      }
    }
  };
  private onTouchEnd = (e: TouchEvent) => {
    for (const t of Array.from(e.changedTouches)) {
      if (this.stick && t.identifier === this.stick.id) this.stick = null;
      if (this.lookTouch && t.identifier === this.lookTouch.id) this.lookTouch = null;
    }
  };

  private bodyForward() {
    _fwd.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    return _fwd;
  }
  private bodyRight() {
    _right.set(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    return _right;
  }

  private blocked(x: number, z: number, radius = 0.55) {
    for (const s of this.solids) {
      if (s.max.y < 0.6) continue;
      const cx = Math.max(s.min.x, Math.min(x, s.max.x));
      const cz = Math.max(s.min.z, Math.min(z, s.max.z));
      const dx = x - cx;
      const dz = z - cz;
      if (dx * dx + dz * dz < radius * radius) return true;
    }
    return false;
  }

  private collide(pos: THREE.Vector3, radius = 0.35) {
    for (const s of this.solids) {
      const cx = Math.max(s.min.x, Math.min(pos.x, s.max.x));
      const cz = Math.max(s.min.z, Math.min(pos.z, s.max.z));
      const dx = pos.x - cx;
      const dz = pos.z - cz;
      const d2 = dx * dx + dz * dz;
      if (d2 < radius * radius && pos.y < s.max.y && pos.y + 1.6 > s.min.y) {
        const d = Math.sqrt(d2) || 0.0001;
        pos.x = cx + (dx / d) * radius;
        pos.z = cz + (dz / d) * radius;
      }
    }
  }

  private nearest(max = 2.6) {
    let best: Npc | null = null;
    let bestD = max;
    const px = this.yawObj.position.x;
    const pz = this.yawObj.position.z;
    for (const n of this.npcs) {
      if (n.hp <= 0 || n.kind === "critter") continue;
      const d = Math.hypot(n.mesh.position.x - px, n.mesh.position.z - pz);
      if (d < bestD) {
        best = n;
        bestD = d;
      }
    }
    return best;
  }

  private nearestGift(max = 1.85) {
    if (this.phase !== "gift") return null;
    let best: Gift | null = null;
    let bestD = max;
    const px = this.yawObj.position.x;
    const pz = this.yawObj.position.z;
    for (const g of this.gifts) {
      if (!g.mesh.visible) continue;
      const d = Math.hypot(g.mesh.position.x - px, g.mesh.position.z - pz);
      if (d < bestD) {
        best = g;
        bestD = d;
      }
    }
    return best;
  }

  private nearFairy(max = 3.4) {
    if (!this.fairy || this.fairy.gone) return false;
    const p = this.yawObj.position;
    const f = this.fairy.mesh.position;
    return Math.hypot(p.x - f.x, p.z - f.z) < max;
  }

  private behind(n: Npc) {
    _tmp.set(this.yawObj.position.x - n.mesh.position.x, 0, this.yawObj.position.z - n.mesh.position.z).normalize();
    const fwd = new THREE.Vector3(0, 0, 1).applyAxisAngle(_up, n.mesh.rotation.y);
    return _tmp.dot(fwd) < -0.15;
  }

  private dialogTalk(): HudSnap["talk"] {
    if (this.hobNode && this.talkOn?.id === "hob") {
      const node = HOB_TALK[this.hobNode];
      if (node) return { name: "Hob", line: node.line, choices: node.choices };
    }
    if (this.dogNode && this.talkOn?.kind === "hound") {
      const node = DOG_TALK[this.dogNode];
      if (node) return { name: "Bramble", line: node.line, choices: node.choices };
    }
    if (this.fairyTalk) return { name: "Nix", line: this.fairyTalk };
    if (this.talkOn) {
      return {
        name: this.talkOn.name,
        line: (this.talkOn.mesh.userData.lastLine as string) ?? this.talkOn.lines[0],
      };
    }
    return null;
  }

  private openHob(n: Npc) {
    this.talkOn = n;
    this.fairyTalk = null;
    this.hobNode = n.ally ? "ally" : "open";
    const node = HOB_TALK[this.hobNode];
    n.mesh.userData.lastLine = node.line;
    this.log("Hob folds a ledger that is mostly threats.");
    this.emit();
  }

  private pickChoice(i: number) {
    if (this.dogNode && this.talkOn?.kind === "hound") {
      const node = DOG_TALK[this.dogNode];
      const choice = node?.choices[i];
      if (choice) this.applyDogChoice(choice.id);
      return;
    }
    if (!this.hobNode || this.talkOn?.id !== "hob") return;
    const node = HOB_TALK[this.hobNode];
    const choice = node?.choices[i];
    if (!choice) return;
    this.applyHobChoice(choice.id);
  }

  private applyHobChoice(id: string) {
    const hob = this.npcs.find((n) => n.id === "hob");
    if (!hob || this.talkOn !== hob) return;
    if (id === "leave") {
      this.hobNode = null;
      this.log("Hob goes back to counting.");
      this.emit();
      return;
    }
    if (id === "pay4" || id === "pay6") {
      const cost = id === "pay4" ? 4 : 6;
      if (this.player.coin < cost) {
        this.hobNode = "broke";
        hob.mesh.userData.lastLine = HOB_TALK.broke.line;
        this.log("Hob sniffs the purse. Dust.");
        this.emit();
        return;
      }
      this.player.coin -= cost;
      this.player.heat = Math.max(0, this.player.heat - 1);
      if (id === "pay6") this.invited = true;
      this.hobNode = id === "pay4" ? "paid4" : "paid6";
      hob.mesh.userData.lastLine = HOB_TALK[this.hobNode].line;
      this.log(id === "pay6" ? "Hob writes a name that wasn't there." : "Hob looks at a wall.");
      this.emit();
      return;
    }
    if (id === "recruit_steal" || id === "recruit_split") {
      hob.ally = true;
      hob.hostile = false;
      hob.hp = Math.max(hob.hp, 70);
      this.hobNode = "recruited";
      hob.mesh.userData.lastLine = HOB_TALK.recruited.line;
      this.log(
        id === "recruit_split"
          ? "Hob pockets a contract he invented. He's yours."
          : "Hob shuts the ledger. The tax has a knife now.",
      );
      this.emit();
      return;
    }
    if (HOB_TALK[id]) {
      this.hobNode = id;
      hob.mesh.userData.lastLine = HOB_TALK[id].line;
      this.emit();
    }
  }

  private openDog(n: Npc) {
    this.talkOn = n;
    this.fairyTalk = null;
    this.hobNode = null;
    this.dogNode = "open";
    n.mesh.userData.lastLine = DOG_TALK.open.line;
    n.sitT = Math.max(n.sitT, 2);
    this.log("The hound has outlived three tax policies.");
    this.emit();
  }

  private applyDogChoice(id: string) {
    const dog = this.npcs.find((n) => n.kind === "hound");
    if (!dog || this.talkOn !== dog) return;
    if (id === "leave") {
      this.dogNode = null;
      this.log("Bramble returns to the important work of existing.");
      this.emit();
      return;
    }
    if (id === "pet" || id === "petmore") {
      dog.sitT = 12;
      this.dogNode = id === "pet" ? "pet" : "petmore";
      dog.mesh.userData.lastLine = DOG_TALK[this.dogNode].line;
      this.log(id === "pet" ? "You scratch. A kingdom notices nothing." : "He leans. You are, briefly, a good person.");
      this.emit();
      return;
    }
    if (DOG_TALK[id]) {
      this.dogNode = id;
      dog.mesh.userData.lastLine = DOG_TALK[id].line;
      this.emit();
    }
  }

  private doTalk() {
    if (this.phase === "gift") {
      const gift = this.nearestGift();
      if (gift) {
        this.takeGift(gift.id);
        return;
      }
      if (this.nearFairy()) {
        const i = Math.floor(this.clock * 0.35) % NIX_LINES.length;
        this.fairyTalk = NIX_LINES[i];
        this.player.tongue += 1;
        this.log("You speak with Nix.");
        this.emit();
        return;
      }
    }
    const n = this.nearest();
    if (!n) {
      this.talkOn = null;
      this.hobNode = null;
      this.dogNode = null;
      this.emit();
      return;
    }
    this.player.tongue += 1;
    this.talkOn = n;
    this.hobNode = n.id === "hob" ? (n.ally ? "ally" : "open") : null;
    this.dogNode = n.kind === "hound" ? "open" : null;
    if (n.id === "hob") {
      this.openHob(n);
      return;
    }
    if (n.kind === "hound") {
      this.openDog(n);
      return;
    }
    const line = n.lines[Math.floor(Math.random() * n.lines.length)];
    n.mesh.userData.lastLine = line;
    this.log(`You speak with ${n.name}.`);
    this.emit();
  }

  private doPocket() {
    if (this.phase === "gift") {
      if (this.nearFairy()) {
        this.takeFeather();
        return;
      }
      this.log("Her coat. Get closer — or pick a gift from the mud.");
      this.emit();
      return;
    }
    if (this.path !== "feather") {
      this.log("Your hands are bricks. Nix keeps the clever ones.");
      this.emit();
      return;
    }
    const n = this.nearest(2.4);
    if (!n) return;
    if (n.picked) {
      this.log(`${n.name} is already lighter.`);
      this.emit();
      return;
    }
    const sneak = this.behind(n);
    const catchChance = sneak ? 0.04 : 0.16;
    if (Math.random() < catchChance) {
      n.hostile = true;
      this.player.heat += 1;
      this.log(`${n.name} catches even feather hands. Heat rises.`);
      this.emit();
      return;
    }
    n.picked = true;
    this.player.coin += n.purse + 2;
    this.player.shadow += 1;
    this.log(`Feather hands. ${n.purse + 2} coin from ${n.name}.`);
    this.tone(210, 0.1);
    this.emit();
  }

  private poseSword(u: number) {
    if (u < 0.18) {
      const k = u / 0.18;
      this.sword.position.set(0.42, -0.34 + k * 0.1, -0.6);
      this.sword.rotation.set(-0.12 - k * 0.4, 0.35, -0.18 + k * 0.15);
    } else if (u < 0.5) {
      const k = (u - 0.18) / 0.32;
      this.sword.position.set(0.42 - k * 0.18, -0.24 - k * 0.06, -0.6 + k * 0.2);
      this.sword.rotation.set(-0.52 + k * 1.1, 0.35 - k * 0.25, -0.03 - k * 0.9);
    } else {
      const k = (u - 0.5) / 0.5;
      this.sword.position.set(0.24 + k * 0.18, -0.3 - k * 0.04, -0.4 - k * 0.2);
      this.sword.rotation.set(-0.12 + (1 - k) * 0.2, 0.35, -0.18 - (1 - k) * 0.3);
    }
  }

  private swing() {
    if (this.path !== "steel") {
      if (this.phase !== "boot") this.log("No sword. The ditch offered. You declined.");
      this.emit();
      return;
    }
    if (this.swinging > 0) return;
    this.swinging = 0.4;
    this.player.steel += 1;
    this.tone(160, 0.08);
    this.camera.getWorldDirection(_tmp);
    const origin = this.camera.getWorldPosition(new THREE.Vector3());
    for (const n of this.npcs) {
      if (n.hp <= 0 || n.ally || n.kind !== "person") continue;
      const to = n.mesh.position.clone().add(new THREE.Vector3(0, 1, 0)).sub(origin);
      const dist = to.length();
      if (dist > 2.4) continue;
      if (_tmp.dot(to.normalize()) > 0.55) {
        n.hp -= 22;
        n.hostile = true;
        this.player.heat += 1;
        this.log(`Steel on ${n.name}.`);
        if (n.hp <= 0) {
          n.mesh.visible = false;
          this.log(`${n.name} goes down.`);
        }
      }
    }
    this.emit();
  }

  private cast() {
    if (this.path !== "spark") {
      if (this.phase === "play") this.log("The page is still blank.");
      this.emit();
      return;
    }
    if (this.spellCd > 0 || this.player.spark < 1) {
      if (this.player.spark < 1) this.log("The charm is ash.");
      this.emit();
      return;
    }
    this.player.spark -= 1;
    this.player.sparkStat += 1;
    this.spellCd = 0.7;
    this.tone(480, 0.12);
    this.camera.getWorldDirection(_tmp);
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 8), new THREE.MeshBasicMaterial({ color: 0xd4893a }));
    mesh.position.copy(this.camera.getWorldPosition(new THREE.Vector3())).add(_tmp.clone().multiplyScalar(0.8));
    const light = new THREE.PointLight(0xd4893a, 1.4, 6);
    mesh.add(light);
    this.scene.add(mesh);
    this.bolts.push({ mesh, vel: _tmp.clone().multiplyScalar(18), life: 1.6 });
    this.log("Spark leaves the book.");
    this.emit();
  }

  private playTune() {
    if (this.path !== "song") return;
    if (this.strumming > 0) return;
    this.strumming = 0.55;
    this.player.tongue += 1;
    this.tone(392, 0.18);
    window.setTimeout(() => this.tone(494, 0.16), 90);
    const n = this.nearest(5.5);
    if (!n) {
      this.log("The ditch applauds. Nobody else does.");
      this.emit();
      return;
    }
    if (n.hostile) {
      if (Math.random() < 0.7) {
        n.hostile = false;
        n.charmed = true;
        this.log(`${n.name} forgets the fight. Music is cheaper than a surgeon.`);
      } else {
        this.log(`${n.name} hates lutes. Fair.`);
      }
      this.emit();
      return;
    }
    n.charmed = true;
    this.invited = true;
    n.mesh.userData.lastLine = CHARM[n.id] ?? `${n.name} nods like a person who has been invited by accident.`;
    this.talkOn = n;
    this.log(n.mesh.userData.lastLine as string);
    this.emit();
  }

  private tick(dt: number) {
    this.clock += dt;
    for (const c of this.clouds) {
      const a = dt * 0.012;
      const x = c.position.x * Math.cos(a) - c.position.z * Math.sin(a);
      const z = c.position.x * Math.sin(a) + c.position.z * Math.cos(a);
      c.position.x = x;
      c.position.z = z;
    }
    for (const f of this.fires) {
      const flick = 0.82 + Math.sin(this.clock * 7.2 + f.seed) * 0.12 + Math.sin(this.clock * 13 + f.seed * 0.3) * 0.08;
      f.light.intensity = f.base * flick;
      f.flame.scale.setScalar(0.85 + flick * 0.2);
    }

    if (this.phase === "wake") {
      const skip =
        this.injected.size > 0 ||
        this.has("KeyW") ||
        this.has("KeyA") ||
        this.has("KeyS") ||
        this.has("KeyD") ||
        this.stick !== null;
      if (skip) this.wakeT = 1;
      this.wakeT = Math.min(1, this.wakeT + dt / 2.2);
      const t = 1 - (1 - this.wakeT) ** 3;
      this.yawObj.position.y = LIE_Y + (STAND_Y - LIE_Y) * t;
      this.pitch = 0.95 + (0.28 - 0.95) * t;
      if (this.fairy && !this.fairy.gone) {
        this.fairy.mesh.position.set(2.6 * (1 - t), 3.6 - 2.2 * t, 23.6 + 0.4 * t);
      }
      if (this.wakeT >= 1) {
        this.phase = "gift";
        this.fairyTalk = NIX_LINES[1];
        this.log("Three gifts in the mud. A fourth in her coat.");
      }
    }

    const canMove =
      this.player.hp > 0 && this.phase !== "boot" && this.phase !== "wake" && this.overlayNow() !== "paused";

    if (canMove) {
      const f = this.bodyForward();
      const r = this.bodyRight();
      _wish.set(0, 0, 0);
      if (this.has("KeyW") || this.has("ArrowUp")) _wish.add(f);
      if (this.has("KeyS") || this.has("ArrowDown")) _wish.sub(f);
      if (this.has("KeyD") || this.has("ArrowRight")) _wish.add(r);
      if (this.has("KeyA") || this.has("ArrowLeft")) _wish.sub(r);
      if (this.stick) {
        _wish.addScaledVector(f, -this.stick.dy);
        _wish.addScaledVector(r, this.stick.dx);
      }
      if (_wish.lengthSq() > 0) _wish.normalize().multiplyScalar(7.2);
      this.vel.x = _wish.x;
      this.vel.z = _wish.z;
      this.vel.y -= 22 * dt;
      if (this.yawObj.position.y <= STAND_Y) {
        this.yawObj.position.y = STAND_Y;
        this.vel.y = 0;
        this.grounded = true;
      } else this.grounded = false;
      if (this.has("Space") && this.grounded) {
        this.vel.y = 7.4;
        this.grounded = false;
      }
      this.yawObj.position.x += this.vel.x * dt;
      this.yawObj.position.y += this.vel.y * dt;
      this.yawObj.position.z += this.vel.z * dt;
      this.collide(this.yawObj.position);
    }

    this.yawObj.rotation.y = this.yaw;
    this.camera.rotation.x = this.pitch;

    if (this.fairy && !this.fairy.gone) {
      this.fairy.t += dt;
      this.fairy.mesh.position.y += Math.sin(this.fairy.t * 2.4) * 0.012;
      const flap = Math.sin(this.fairy.t * 11) * 0.45;
      this.fairy.wings[0].rotation.y = -0.5 + flap;
      this.fairy.wings[1].rotation.y = 0.5 - flap;
      this.fairy.mesh.lookAt(this.yawObj.position.x, this.fairy.mesh.position.y, this.yawObj.position.z);
    } else if (this.fairy && this.fairy.gone) {
      this.fairy.mesh.position.y += 3.2 * dt;
      this.fairy.mesh.position.x += 1.4 * dt;
      const mats = this.fairy.mesh.children;
      for (const c of mats) {
        const m = (c as THREE.Mesh).material as THREE.MeshStandardMaterial | undefined;
        if (m && "opacity" in m) {
          m.transparent = true;
          m.opacity = Math.max(0, (m.opacity ?? 1) - dt * 0.6);
        }
      }
      if (this.fairy.mesh.position.y > 10) this.fairy.mesh.visible = false;
    }

    if (this.phase === "gift") {
      for (const g of this.gifts) {
        if (!g.mesh.visible) continue;
        const lab = g.mesh.children[g.mesh.children.length - 1];
        this.camera.getWorldQuaternion(_quat);
        lab.quaternion.copy(g.mesh.quaternion).invert().multiply(_quat);
      }
    }

    if (this.swinging > 0) {
      this.swinging -= dt;
      const u = 1 - Math.max(0, this.swinging) / 0.4;
      this.poseSword(u);
    } else if (this.path === "steel") {
      const idle = Math.sin(this.clock * 2.1) * 0.02;
      this.sword.position.set(0.42, -0.34 + idle, -0.6);
      this.sword.rotation.set(-0.12 + idle, 0.35, -0.18);
    }
    if (this.strumming > 0) {
      this.strumming -= dt;
      const t = 1 - this.strumming / 0.55;
      this.lute.position.set(0.32, -0.24, -0.5);
      this.lute.rotation.set(0.35, 0.7 + Math.sin(t * Math.PI * 3) * 0.35, -0.25);
    } else if (this.path === "song") {
      const idle = Math.sin(this.clock * 1.8) * 0.02;
      this.lute.position.set(0.32, -0.24 + idle, -0.5);
      this.lute.rotation.set(0.35, 0.7, -0.25);
    }
    if (this.path === "spark") {
      const pulse = this.spellCd > 0 ? Math.sin(this.clock * 18) * 0.08 : Math.sin(this.clock * 1.6) * 0.02;
      this.book.position.set(0.3, -0.22 + pulse, -0.48);
      this.book.rotation.set(0.5 + pulse, 0.4, -0.15);
    }
    this.spellCd = Math.max(0, this.spellCd - dt);
    this.invuln = Math.max(0, this.invuln - dt);
    if (this.path === "spark" && this.player.spark < 6) {
      this.sparkRegen += dt;
      if (this.sparkRegen > 8) {
        this.sparkRegen = 0;
        this.player.spark += 1;
      }
    }

    for (let i = this.bolts.length - 1; i >= 0; i--) {
      const b = this.bolts[i];
      b.mesh.position.addScaledVector(b.vel, dt);
      b.life -= dt;
      for (const n of this.npcs) {
        if (n.hp <= 0 || n.ally || n.kind !== "person") continue;
        if (b.mesh.position.distanceTo(n.mesh.position.clone().setY(1.1)) < 0.7) {
          n.hp -= 26;
          n.hostile = true;
          this.player.heat += 1;
          b.life = 0;
          this.log(`Spark hits ${n.name}.`);
          if (n.hp <= 0) {
            n.mesh.visible = false;
            this.log(`${n.name} drops.`);
          }
        }
      }
      if (b.life <= 0 || b.mesh.position.y < 0) {
        this.scene.remove(b.mesh);
        this.bolts.splice(i, 1);
      }
    }

    _ppos.set(this.yawObj.position.x, 0, this.yawObj.position.z);
    this.camera.getWorldDirection(_fwd);
    _right.crossVectors(_fwd, _up).normalize();
    for (const n of this.npcs) {
      if (n.hp <= 0) continue;
      n.hitCd = Math.max(0, n.hitCd - dt);
      const home = n.mesh.userData.home as THREE.Vector3;
      const tgt = n.mesh.userData.target as THREE.Vector3;
      const limbs = n.mesh.userData.limbs as {
        torso: THREE.Group;
        armL: THREE.Group;
        armR: THREE.Group;
        legL: THREE.Group;
        legR: THREE.Group;
      };
      n.sitT = Math.max(0, n.sitT - dt);
      let moving = false;
      const freeze = this.talkOn === n || (n.kind === "hound" && n.sitT > 0);
      if (freeze) {
        tgt.copy(n.mesh.position);
      } else if (n.ally) {
        const foe = this.npcs.find((o) => o.hostile && o.hp > 0 && !o.ally) ?? null;
        if (foe) {
          tgt.copy(foe.mesh.position).setY(0);
        } else {
          this.camera.getWorldDirection(_fwd);
          tgt.set(
            this.yawObj.position.x - _fwd.x * 1.7,
            0,
            this.yawObj.position.z - _fwd.z * 1.7,
          );
        }
      } else if (n.hostile) {
        tgt.copy(_ppos);
      } else {
        n.wanderT -= dt;
        if (n.wanderT < 0) {
          n.wanderT = n.kind === "critter" ? 0.8 + Math.random() * 1.4 : n.kind === "hound" ? 3 + Math.random() * 3 : n.guard ? 2.4 + Math.random() * 2 : 1.6 + Math.random() * 3;
          const range = n.kind === "critter" ? 5.5 : n.kind === "hound" ? 2.2 : n.guard ? 2.6 : 2.8;
          let nx = home.x + (Math.random() - 0.5) * range * 2;
          let nz = home.z + (n.guard ? (Math.random() - 0.5) * 1.0 : (Math.random() - 0.5) * range);
          if (this.blocked(nx, nz)) {
            nx = home.x;
            nz = home.z;
          }
          tgt.set(nx, 0, nz);
        }
      }
      const dx = tgt.x - n.mesh.position.x;
      const dz = tgt.z - n.mesh.position.z;
      const dist = Math.hypot(dx, dz);
      if (!freeze && dist > 0.18) {
        moving = true;
        const sp = n.kind === "critter" ? 3.1 : n.kind === "hound" ? 0.72 : n.ally ? 2.5 : n.hostile ? 2.3 : n.guard ? 1.05 : 1.25;
        n.mesh.position.x += (dx / dist) * sp * dt;
        n.mesh.position.z += (dz / dist) * sp * dt;
        this.collide(n.mesh.position, n.kind === "critter" ? 0.22 : 0.55);
        n.mesh.position.y = 0;
      }
      n.mesh.rotation.y = Math.atan2(
        this.yawObj.position.x - n.mesh.position.x,
        this.yawObj.position.z - n.mesh.position.z,
      );
      if (n.ally) {
        const foe = this.npcs.find((o) => o.hostile && o.hp > 0 && !o.ally) ?? null;
        if (foe) {
          const fd = Math.hypot(foe.mesh.position.x - n.mesh.position.x, foe.mesh.position.z - n.mesh.position.z);
          if (fd < 1.7 && n.hitCd <= 0) {
            foe.hp -= 14;
            n.hitCd = 0.8;
            this.log("Hob collects.");
            if (foe.hp <= 0) {
              foe.mesh.visible = false;
              this.log(`${foe.name} learns about interest.`);
            }
          }
        }
      } else if (n.hostile && dist < 1.5 && n.hitCd <= 0 && this.invuln <= 0) {
        this.player.hp -= n.guard ? 12 : 8;
        n.hitCd = 0.9;
        this.invuln = 0.35;
        this.log(`${n.name} answers.`);
        if (this.player.hp <= 0) {
          this.log("The page ends in the mud.");
          if (document.pointerLockElement) document.exitPointerLock();
        }
      }
      if (n.kind === "hound") {
        const sitSpr = n.mesh.userData.sitSpr as THREE.Mesh;
        const walkSpr = n.mesh.userData.walkSpr as THREE.Mesh;
        const sitting = freeze || n.sitT > 0;
        if (sitSpr) sitSpr.visible = sitting;
        if (walkSpr) {
          walkSpr.visible = !sitting;
          walkSpr.position.y = 0.4 + (moving ? Math.abs(Math.sin(this.clock * 10)) * 0.05 : 0);
        }
      }
      if (limbs) {
        const t = this.clock * (moving ? 9 : 2.4) + home.x;
        const a = moving ? 0.7 : 0.1;
        limbs.legL.rotation.x = Math.sin(t) * a;
        limbs.legR.rotation.x = Math.sin(t + Math.PI) * a;
        limbs.armL.rotation.x = Math.sin(t + Math.PI) * a * 0.85;
        limbs.armR.rotation.x = Math.sin(t) * a * (n.guard ? 0.28 : 0.85);
        limbs.torso.rotation.z = Math.sin(t * 0.5) * (moving ? 0.06 : 0.025);
        limbs.torso.position.y = 0.14 + Math.sin(this.clock * 2.2 + home.x) * 0.015;
      }
      n.mesh.userData.lab?.quaternion.copy(this.camera.getWorldQuaternion(_quat));
    }

    let prompt = "";
    if (this.phase === "gift") {
      const gift = this.nearestGift();
      if (gift) prompt = gift.hint;
      else if (this.nearFairy()) prompt = "E talk with Nix   ·   F pickpocket her for Feather Hands";
      else prompt = "Sword · lute · spellbook in the mud. Or her pockets.";
    } else if (this.phase === "play") {
      const near = this.nearest();
      if (near) {
        const verbs =
          this.hobNode && near.id === "hob"
            ? "1–4 choose"
            : this.dogNode && near.kind === "hound"
              ? "1–4  ·  pet the old man"
              : near.kind === "hound"
                ? "E talk  ·  pet"
                : this.path === "feather"
                  ? `F pocket${this.behind(near) ? "  (their back is yours)" : ""}`
                  : this.path === "song"
                    ? "click play   E talk"
                    : "E talk";
        prompt = `${near.name}  ·  ${verbs}`;
        if (near.ally) prompt += "  ·  ally";
      } else if (this.talkOn && _ppos.distanceTo(this.talkOn.mesh.position) > 3.2) {
        this.talkOn = null;
        this.hobNode = null;
        this.dogNode = null;
      }
      if (this.invited && !prompt) prompt = "Someone put your name on a list that did not exist this morning.";
    }
    this.emit(prompt);
  }
}

declare global {
  interface Window {
    __controlsTest?: {
      getYaw: () => number;
      getSpeed: () => number;
      setKeys?: (codes: string[]) => void;
      getPos?: () => { x: number; y: number; z: number; phase: string; path: string };
      act?: (a: HudAction) => void;
    };
  }
}
