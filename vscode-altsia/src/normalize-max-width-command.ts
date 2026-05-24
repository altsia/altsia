import * as vscode from 'vscode';

const ALTSIA_CONFIGURATION_SECTION = 'altsia';
const NORMALIZE_MAX_WIDTH_KEY = 'normalize.maxWidth';
const DEFAULT_NORMALIZE_MAX_WIDTH = 80;
const MIN_NORMALIZE_MAX_WIDTH = 20;
const PRESET_NORMALIZE_MAX_WIDTHS = [40, 60, 80, 100, 120];

type NormalizeMaxWidthQuickPickItem = vscode.QuickPickItem & {
  itemType: 'default' | 'preset' | 'custom';
  value?: number;
};

export function getNormalizeMaxWidth(): number | undefined {
  const maxWidth = vscode.workspace
    .getConfiguration(ALTSIA_CONFIGURATION_SECTION)
    .get<number>(NORMALIZE_MAX_WIDTH_KEY);

  if (maxWidth === undefined || !Number.isFinite(maxWidth)) {
    return undefined;
  }

  return Math.trunc(maxWidth);
}

export function registerSetNormalizeMaxWidthCommand(): vscode.Disposable {
  return vscode.commands.registerCommand('altsia.normalize.maxWidth.set', async () => {
    const currentMaxWidth = getNormalizeMaxWidth() ?? DEFAULT_NORMALIZE_MAX_WIDTH;
    const pickItems: NormalizeMaxWidthQuickPickItem[] = [
      {
        itemType: 'default',
        label: `Use Default (${DEFAULT_NORMALIZE_MAX_WIDTH})`,
        description:
          currentMaxWidth === DEFAULT_NORMALIZE_MAX_WIDTH ? 'Current' : 'Reset to extension default',
      },
      ...PRESET_NORMALIZE_MAX_WIDTHS.map((value) => ({
        itemType: 'preset' as const,
        label: `${value}`,
        value,
        description: currentMaxWidth === value ? 'Current' : undefined,
      })),
      {
        itemType: 'custom',
        label: 'Custom...',
        description: 'Input any integer >= 20',
      },
    ];

    const picked = await vscode.window.showQuickPick(pickItems, {
      title: 'Altsia Normalize Max Width',
      placeHolder: 'Select max width for Altsia normalize',
    });

    if (!picked) {
      return;
    }

    if (picked.itemType === 'default') {
      await updateNormalizeMaxWidth(undefined);
      vscode.window.showInformationMessage(
        `Altsia normalize max width is now ${DEFAULT_NORMALIZE_MAX_WIDTH}.`
      );
      return;
    }

    if (picked.itemType === 'preset') {
      if (picked.value === undefined) {
        return;
      }
      await updateNormalizeMaxWidth(picked.value);
      vscode.window.showInformationMessage(`Altsia normalize max width is now ${picked.value}.`);
      return;
    }

    const input = await vscode.window.showInputBox({
      title: 'Altsia Normalize Max Width',
      prompt: 'Enter max width (integer >= 20)',
      value: String(currentMaxWidth),
      validateInput: (value) => {
        const parsed = parseNormalizeMaxWidth(value);
        if (parsed === undefined) {
          return 'Please enter an integer greater than or equal to 20.';
        }
        return undefined;
      },
    });

    if (input === undefined) {
      return;
    }

    const parsed = parseNormalizeMaxWidth(input);
    if (parsed === undefined) {
      return;
    }

    await updateNormalizeMaxWidth(parsed);
    vscode.window.showInformationMessage(`Altsia normalize max width is now ${parsed}.`);
  });
}

function parseNormalizeMaxWidth(value: string): number | undefined {
  const trimmed = value.trim();
  if (!/^\d+$/.test(trimmed)) {
    return undefined;
  }

  const parsed = Number.parseInt(trimmed, 10);
  if (!Number.isFinite(parsed) || parsed < MIN_NORMALIZE_MAX_WIDTH) {
    return undefined;
  }

  return parsed;
}

async function updateNormalizeMaxWidth(value: number | undefined): Promise<void> {
  await vscode.workspace
    .getConfiguration(ALTSIA_CONFIGURATION_SECTION)
    .update(NORMALIZE_MAX_WIDTH_KEY, value, vscode.ConfigurationTarget.Global);
}
