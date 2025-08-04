import { MSAData, SecondaryStructure } from '../types';
export declare class DataLoader {
    /**
     * Load MSA data from API URL
     */
    static loadMSAData(apiUrl: string): Promise<MSAData & {
        notation?: SecondaryStructure;
    }>;
}
