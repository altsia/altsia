export class Debouncer {
  private timer: NodeJS.Timeout | undefined;

  constructor(private readonly delayMs: number) { }

  schedule(action: () => void): void {
    this.cancel();
    this.timer = setTimeout(() => {
      this.timer = undefined;
      action();
    }, this.delayMs);
  }

  cancel(): void {
    if (!this.timer) {
      return;
    }
    clearTimeout(this.timer);
    this.timer = undefined;
  }
}
