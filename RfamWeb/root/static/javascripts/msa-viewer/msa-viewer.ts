import { MSAData, SecondaryStructure } from './types';
import { DataLoader } from './core/data-loader';
import { validateMSAData } from './core/validators';
import { handleLabelClick } from './utils/rnacentral-utils';
import { loadNightingaleComponents } from './utils/nightingale-loader';
import { NavigationTrack } from './tracks/navigation/navigation-track';
import { LinksTrack } from './tracks/links/links-track';
import { SequenceTrack } from './tracks/sequence/sequence-track';
import { MSATrack } from './tracks/msa/msa-track';
import { MSAViewerGetters } from './getters';
import { MSAViewerSetters } from './setters';

export class MSAViewer extends HTMLElement {
  // Public properties (accessible to getters/setters)
  public _data?: MSAData & { notation?: SecondaryStructure };
  public _apiEndpoint?: string;
  public _identifier?: string;
  public _apiUrl?: string;
  public _loading = false;
  public _error?: string;
  public _nightingaleLoaded = false;
  public _sequenceLength = 0;
  public _height = 400;
  public _width = 800;
  public _labelWidth = 200;
  public _displayStart = 1;
  public _displayEnd = 80;
  
  private _navigationTrack?: NavigationTrack;
  private _linksTrack?: LinksTrack;
  private _secondaryStructureTrack?: SequenceTrack;
  private _consensusTrack?: SequenceTrack;
  private _msaTrack?: MSATrack;
  private _scrollboxObserver?: IntersectionObserver;
  
  constructor() {
    super();
    this.className = 'msa-viewer';
    this.loadNightingale();
  }

  static get observedAttributes(): string[] {
    return ['api-endpoint', 'identifier', 'api-url', 'height', 'width', 'label-width'];
  }

  // Getters using external class
  get apiEndpoint(): string | undefined { return MSAViewerGetters.getApiEndpoint(this); }
  get identifier(): string | undefined { return MSAViewerGetters.getIdentifier(this); }
  get height(): number { return MSAViewerGetters.getHeight(this); }
  get width(): number { return MSAViewerGetters.getWidth(this); }
  get labelWidth(): number { return MSAViewerGetters.getLabelWidth(this); }

  // Setters using external class
  set apiEndpoint(value: string | undefined) { MSAViewerSetters.setApiEndpoint(this, value); }
  set identifier(value: string | undefined) { MSAViewerSetters.setIdentifier(this, value); }
  set height(value: number) { MSAViewerSetters.setHeight(this, value); }
  set width(value: number) { MSAViewerSetters.setWidth(this, value); }
  set labelWidth(value: number) { MSAViewerSetters.setLabelWidth(this, value); }

  // Zoom methods
  public zoomIn(): void {
    this._navigationTrack?.zoomIn();
  }

  public zoomOut(): void {
    this._navigationTrack?.zoomOut();
  }

  private async loadNightingale(): Promise<void> {
    try {
      await loadNightingaleComponents();
      this._nightingaleLoaded = true;
      if (this._data) {
        this.render();
      }
    } catch (error) {
      this._error = 'Failed to load MSA visualization library';
      this.render();
    }
  }

  // Public methods (needed by setters)
  public updateApiUrl(): void {
    if (this._apiEndpoint && this._identifier) {
      const endpoint = this._apiEndpoint.replace(/\/$/, '');
      this._apiUrl = `${endpoint}/${this._identifier}`;
      this.loadDataFromApi();
    }
  }

  public updateTrackConfig(config: Partial<any>): void {
    // For now, we'll re-render when config changes
    if (this._data) {
      this.render();
    }
  }

  async connectedCallback(): Promise<void> {
    const apiEndpointAttr = this.getAttribute('api-endpoint');
    const identifierAttr = this.getAttribute('identifier');
    
    if (apiEndpointAttr && identifierAttr) {
      this.apiEndpoint = apiEndpointAttr;
      this.identifier = identifierAttr;
    }
  }

  disconnectedCallback(): void {
    // Clean up intersection observer
    if (this._scrollboxObserver) {
      this._scrollboxObserver.disconnect();
      this._scrollboxObserver = undefined;
    }
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string): void {
    if (oldValue !== newValue) {
      switch (name) {
        case 'api-endpoint':
          this.apiEndpoint = newValue;
          break;
        case 'identifier':
          this.identifier = newValue;
          break;
        case 'height':
          this.height = parseInt(newValue) || 400;
          break;
        case 'width':
          this.width = parseInt(newValue) || 800;
          break;
        case 'label-width':
          this.labelWidth = parseInt(newValue) || 200;
          break;
      }
    }
  }

  private async loadDataFromApi(): Promise<void> {
    if (!this._apiUrl) return;
    
    this._loading = true;
    this._error = undefined;
    this.render();
    
    try {
      const data = await DataLoader.loadMSAData(this._apiUrl);
      if (validateMSAData(data)) {
        this._data = data;
        this._sequenceLength = Math.max(...data.sequences.map(seq => seq.sequence.length));
        
        // Always start at position 1 and set end based on sequence length
        this._displayStart = 1;
        this._displayEnd = this.getDefaultDisplayEnd(this._sequenceLength);
      } else {
        this._error = 'Invalid MSA data format';
      }
    } catch (error) {
      this._error = error instanceof Error ? error.message : 'Unknown error';
    } finally {
      this._loading = false;
      this.render();
    }
  }

  private getDefaultDisplayEnd(sequenceLength: number, defaultValue: number = 80): number {
    return Math.min(sequenceLength, defaultValue);
  }

  private render(): void {
    if (this._loading) {
      this.innerHTML = '<div class="msa-loading">Loading...</div>';
      return;
    }

    if (this._error) {
      this.innerHTML = `<div class="msa-error">${this._error}</div>`;
      return;
    }

    if (!this._nightingaleLoaded) {
      this.innerHTML = '<div class="msa-loading">Loading components...</div>';
      return;
    }

    if (!this._data) {
      this.innerHTML = '<div class="msa-error">No data</div>';
      return;
    }

    this.renderTracks();
  }

  private renderTracks(): void {
    if (!this._data) return;

    // Create track configuration
    const trackConfig = {
      height: this._height,
      width: this._width,
      labelWidth: this._labelWidth,
      sequenceLength: this._sequenceLength,
      displayStart: this._displayStart,
      displayEnd: this._displayEnd
    };

    const trackData = {
      msaData: this._data,
      notation: this._data.notation
    };

    // Create track instances
    this._navigationTrack = new NavigationTrack(trackConfig, trackData);
    this._msaTrack = new MSATrack(trackConfig, trackData);
    
    // Create secondary structure track if secondary structure data exists
    if (this._data.notation) {
      this._linksTrack = new LinksTrack(trackConfig, trackData);
      this._secondaryStructureTrack = new SequenceTrack(
        { 
          ...trackConfig, 
          label: 'Notation', 
          dataSource: 'notation',
          sequenceName: 'Notation'
        }, 
        trackData
      );
    }
    
    // Create consensus track if consensus data exists
    if (this._data.consensus) {
      this._consensusTrack = new SequenceTrack(
        { 
          ...trackConfig, 
          label: 'Consensus', 
          dataSource: 'consensus',
          sequenceName: 'Consensus'
        }, 
        trackData
      );
    }

    // Generate HTML using track classes
    const navigationHTML = this._navigationTrack.createHTML();
    const linksHTML = this._linksTrack ? this._linksTrack.createHTML() : '';
    const secondaryStructureHTML = this._secondaryStructureTrack ? this._secondaryStructureTrack.createHTML() : '';
    const consensusHTML = this._consensusTrack ? this._consensusTrack.createHTML() : '';
    const msaHTML = this._msaTrack.createHTML();

    // Create single MSA track with all sequences in scrollbox
    const allSequences = this._data.sequences;

    // Single MSA track with all sequences
    const msaWithScrollbox = `
      <nightingale-scrollbox 
        id="msa-scrollbox" 
        root-margin="50px" 
        disable-scroll-with-ctrl
        style="width: 100%; display: block;">
        <nightingale-scrollbox-item id="msa-item-main">
          ${msaHTML}
        </nightingale-scrollbox-item>
      </nightingale-scrollbox>
    `;

    // Set up the main container with configurable width
    this.innerHTML = `
      <nightingale-manager style="width: ${this._width}px;">
        ${navigationHTML}
        ${linksHTML}
        ${secondaryStructureHTML}
        ${consensusHTML}
        ${msaWithScrollbox}
      </nightingale-manager>
    `;

    // Setup tracks after DOM is ready
    setTimeout(() => {
      const container = this.querySelector('nightingale-manager') as HTMLElement;
      if (container) {
        this._navigationTrack?.setup(container);
        this._linksTrack?.setup(container);
        this._secondaryStructureTrack?.setup(container);
        this._consensusTrack?.setup(container);
        
        this._msaTrack?.setup(container);
        
        // Set up MSA data for the single scrollbox item
        const scrollboxElement = container.querySelector('#msa-scrollbox');
        if (scrollboxElement) {
          const msaElement = container.querySelector('#msa-track') as HTMLElement;
          if (msaElement && allSequences.length > 0) {
            (msaElement as any).data = allSequences;
          }
        }
        
        // Setup event delegation for label clicks
        this.setupEventDelegation();
      }
    }, 200);
  }
  
  private setupEventDelegation(): void {
    this.removeEventListener('click', this.handleLabelClick);
    this.addEventListener('click', this.handleLabelClick);
  }

  private handleLabelClick = (event: Event): void => {
    handleLabelClick(event, this, (url: string) => {
      window.open(url, '_blank', 'noopener,noreferrer');
    });
  };
}

if (!customElements.get('msa-viewer')) {
  customElements.define('msa-viewer', MSAViewer);
}