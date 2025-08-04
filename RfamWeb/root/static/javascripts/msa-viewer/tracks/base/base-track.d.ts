import { MSAData, SecondaryStructure } from '../../types';
export interface TrackConfig {
    height: number;
    labelWidth: number;
    sequenceLength: number;
    displayStart: number;
    displayEnd: number;
}
export interface TrackData {
    msaData: MSAData;
    notation?: SecondaryStructure;
}
export declare abstract class BaseTrack {
    protected config: TrackConfig;
    protected data: TrackData;
    protected element?: HTMLElement;
    protected trackId: string;
    constructor(trackId: string, config: TrackConfig, data: TrackData);
    /**
     * Create the HTML structure for this track
     */
    abstract createHTML(): string;
    /**
     * Setup the track after HTML is rendered
     */
    abstract setup(container: HTMLElement): void;
    /**
     * Update the track when data or config changes
     */
    abstract update(config?: Partial<TrackConfig>, data?: Partial<TrackData>): void;
    /**
     * Clean up the track
     */
    abstract destroy(): void;
    /**
     * Get the track element
     */
    getElement(): HTMLElement | undefined;
    /**
     * Update configuration
     */
    updateConfig(newConfig: Partial<TrackConfig>): void;
    /**
     * Update data
     */
    updateData(newData: Partial<TrackData>): void;
    /**
     * Check if track has required data
     */
    protected hasRequiredData(): boolean;
    /**
     * Get common nightingale attributes
     */
    protected getNightingaleAttributes(): Record<string, string>;
    /**
     * Apply attributes to an element
     */
    protected applyAttributes(element: HTMLElement, attributes: Record<string, string>): void;
    /**
     * Create label HTML
     */
    protected createLabel(text: string): string;
}
