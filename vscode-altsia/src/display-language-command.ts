import * as vscode from 'vscode';
import { DISPLAY_LANGUAGE_OPTIONS, DISPLAY_LANGUAGE_STATE_KEY } from './languages';

interface RegisterSetDisplayLanguageCommandOptions {
  context: vscode.ExtensionContext;
  getDisplayLanguage: () => string;
  setDisplayLanguage: (language: string) => void;
  onDisplayLanguageChanged: () => Promise<void>;
}

type DisplayLanguageQuickPickItem = vscode.QuickPickItem & {
  itemType: 'default' | 'language';
  value?: string;
};

export function getInitialDisplayLanguage(context: vscode.ExtensionContext): string {
  return resolveSupportedLanguageCode(
    context.globalState.get<string>(DISPLAY_LANGUAGE_STATE_KEY) ?? vscode.env.language
  );
}

export function registerSetDisplayLanguageCommand(
  options: RegisterSetDisplayLanguageCommandOptions
): vscode.Disposable {
  return vscode.commands.registerCommand('altsia.displayLanguage.set', async () => {
    const defaultLanguage = resolveSupportedLanguageCode(vscode.env.language);
    const currentLanguage = options.getDisplayLanguage();
    const pickItems: DisplayLanguageQuickPickItem[] = [
      {
        itemType: 'default',
        label: `Use VS Code Default: ${formatDisplayLanguageLabel(defaultLanguage)}`,
        description: 'Use vscode.env.language',
      },
      ...DISPLAY_LANGUAGE_OPTIONS.map((option) => ({
        itemType: 'language' as const,
        label: option.label,
        value: option.value,
        description:
          option.value.toLowerCase() === currentLanguage.toLowerCase() ? 'Current' : undefined,
      })),
    ];

    const picked = await vscode.window.showQuickPick(pickItems, {
      title: 'Altsia Display Language',
      placeHolder: 'Select from all available languages',
    });

    if (!picked) {
      return;
    }

    if (picked.itemType === 'default') {
      await options.context.globalState.update(DISPLAY_LANGUAGE_STATE_KEY, undefined);
      options.setDisplayLanguage(defaultLanguage);
    } else {
      if (!picked.value) {
        return;
      }
      options.setDisplayLanguage(picked.value);
      await options.context.globalState.update(DISPLAY_LANGUAGE_STATE_KEY, picked.value);
    }

    await options.onDisplayLanguageChanged();

    vscode.window.showInformationMessage(
      `Altsia display language is now ${formatDisplayLanguageLabel(options.getDisplayLanguage())}.`
    );
  });
}

function normalizeLanguageCode(value: string): string {
  const normalizedValue = value.trim().replace(/_/g, '-');
  const parts = normalizedValue.split('-').filter((part) => part.length > 0);

  if (parts.length === 0) {
    return 'en';
  }

  const [language, ...suffixes] = parts;
  const normalizedSuffixes = suffixes.map((suffix) => {
    if (suffix.length === 2) {
      return suffix.toUpperCase();
    }
    if (suffix.length === 4) {
      return `${suffix[0].toUpperCase()}${suffix.slice(1).toLowerCase()}`;
    }
    return suffix;
  });

  return [language.toLowerCase(), ...normalizedSuffixes].join('-');
}

function resolveSupportedLanguageCode(value: string): string {
  const normalizedValue = normalizeLanguageCode(value);
  const matchedOption = DISPLAY_LANGUAGE_OPTIONS.find(
    (option) => option.value.toLowerCase() === normalizedValue.toLowerCase()
  );
  return matchedOption?.value ?? normalizedValue;
}

function formatDisplayLanguageLabel(value: string): string {
  const normalizedValue = resolveSupportedLanguageCode(value);
  const matchedOption = DISPLAY_LANGUAGE_OPTIONS.find(
    (option) => option.value.toLowerCase() === normalizedValue.toLowerCase()
  );
  return matchedOption?.label ?? `Unknown Language (${normalizedValue})`;
}
