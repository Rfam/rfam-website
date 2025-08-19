export interface MSASequence {
    name: string;
    sequence: string;
}
export interface MSAData {
    sequences: MSASequence[];
    consensus?: string;
}
export interface BasePair {
    x: number;
    y: number;
    score: number;
}
export interface SecondaryStructure {
    consensus: string;
    basePairs?: BasePair[];
}
