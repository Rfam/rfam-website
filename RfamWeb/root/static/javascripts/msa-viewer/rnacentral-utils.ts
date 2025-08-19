export function extractUrl(label: string): string | null {
  // Parse label format: URS0000D6CB1B_12908/1-56
  const match = label.match(/^(URS[A-F0-9]+)_(\d+)\/(.+)$/);
  
  if (match) {
    const [, ursId, taxonId] = match;
    return `https://rnacentral.org/rna/${ursId}/${taxonId}`;
  }
  else {
    const enaId = label.split('.')[0];
    return `https://www.ebi.ac.uk/ena/browser/view/${enaId}`;
  }
}


export function handleLabelClick(
  event: Event,
  componentElement: HTMLElement,
  onUrlFound?: (url: string, target: HTMLElement) => void
): void {
  const target = event.target as HTMLElement;
  
  // Only handle clicks that are:
  // 1. Inside a nightingale-msa element AND
  // 2. Either have active-label attribute or are within an element that has it
  const msaElement = target.closest('nightingale-msa');
  if (!msaElement) {
    return; // Not inside an MSA element at all
  }
  
  // Check if this click is on a label (has active-label attribute or is within one)
  const hasActiveLabel = target.hasAttribute('active-label') || target.closest('[active-label]');
  if (!hasActiveLabel) {
    return; // Not a label click
  }
  
  let labelText = target.textContent?.trim();
  
  // If no text content, check for active-label attribute
  if (!labelText && target.hasAttribute('active-label')) {
    labelText = target.getAttribute('active-label')?.trim();
  }
  
  // Also check parent elements for active-label
  if (!labelText) {
    let currentElement = target;
    while (currentElement && currentElement !== componentElement) {
      if (currentElement.hasAttribute('active-label')) {
        labelText = currentElement.getAttribute('active-label')?.trim();
        break;
      }
      currentElement = currentElement.parentElement as HTMLElement;
    }
  }
  
  if (!labelText) return;
  
  const url = extractUrl(labelText);
  if (url) {
    if (onUrlFound) {
      onUrlFound(url, target);
    } else {
      // Default behavior: open in new tab
      window.open(url, '_blank', 'noopener,noreferrer');
    }
    
    event.preventDefault();
    event.stopPropagation();
  }
}