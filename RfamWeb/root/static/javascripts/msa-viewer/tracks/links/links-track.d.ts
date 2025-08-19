import { BaseTrack, TrackConfig, TrackData } from '../base/base-track';
export declare class LinksTrack extends BaseTrack {
    constructor(config: TrackConfig, data: TrackData);
    createHTML(): string;
    setup(container: HTMLElement): void;
    update(config?: Partial<TrackConfig>, data?: Partial<TrackData>): void;
    destroy(): void;
    private setupNightingaleLinks;
}
