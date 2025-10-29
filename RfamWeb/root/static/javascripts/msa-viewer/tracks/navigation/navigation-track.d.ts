import { BaseTrack, TrackConfig, TrackData } from '../base/base-track';
export declare class NavigationTrack extends BaseTrack {
    private navigationElement?;
    constructor(config: TrackConfig, data: TrackData);
    createHTML(): string;
    setup(container: HTMLElement): void;
    update(config?: Partial<TrackConfig>, data?: Partial<TrackData>): void;
    destroy(): void;
    /**
     * Get the navigation element for zoom operations
     */
    getNavigationElement(): HTMLElement | undefined;
    /**
     * Zoom in
     */
    zoomIn(): void;
    /**
     * Zoom out
     */
    zoomOut(): void;
    private setupNavigationTrack;
    private setupZoomControls;
}
