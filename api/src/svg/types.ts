// Special effect
type ZIndexAttr = "below-dick"
type BgAttr = "bg-stars"
type DickSkin = "dick-waves" | "pink-balls" | "red-balls" | "prepuce" | "green-balls-hairs"
type HatAttr = "female-cycloid" | "male-cycloid"

export type AccessoryAttr = ZIndexAttr | BgAttr | DickSkin | HatAttr

export interface Accessory {
    name: string // Used as an id
    value: string | ((props?: any) => string) // like #HEX or <svg/>
    attr?: AccessoryAttr[] // like z-index
    defs?: string[] // For linear gradients
    children?: Accessory[]
}
