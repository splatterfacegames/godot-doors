// The demo loader and the reel.
const loadButton = document.querySelector("[data-load-demo]");
const demoStage = document.querySelector("[data-demo-stage]");

loadButton?.addEventListener("click", () => {
  const frame = document.createElement("iframe");
  frame.src = "/play/";
  frame.title = "Ashcombe House, the godot-doors demo";
  frame.allow = "fullscreen; gamepad; autoplay";
  demoStage.append(frame);
  frame.focus();
  frame.addEventListener("load", () => frame.contentWindow?.focus());
});

// The reel plays only when motion is welcome; else it shows its poster
// and the controls.
const reel = document.querySelector(".reel-video");
if (reel && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  reel.removeAttribute("autoplay");
  reel.pause();
  reel.controls = true;
}
