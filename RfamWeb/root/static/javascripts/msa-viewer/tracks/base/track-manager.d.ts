import { BaseTrack, TrackConfig, TrackData } from './base-track';
export declare class TrackManager {
    private tracks;
    private container;
    private config;
    private data;
    constructor(container: HTMLElement, config: TrackConfig, data: TrackData);
    /**
     * Register a track
     */
    registerTrack(trackId: string, track: BaseTrack): void;
    /**
     * Remove a track
     */
    removeTrack(trackId: string): void;
    /**
     * Get a track by ID
     */
    getTrack(trackId: string): BaseTrack | undefined;
    /**
     * Get all track IDs
     */
    getTrackIds(): string[];
    /**
     * Update all tracks with new config
     */
    updateConfig(newConfig: Partial<TrackConfig>): void;
    /**
     * Update all tracks with new data
     */
    updateData(newData: Partial<TrackData>): void;
    /**
     * Render all tracks
     */
    render(): void;
    /**
     * Destroy all tracks
     */
    destroy(): void;
}
