--!strict
type ExpectResult = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toThrow: (message: string?) -> (),
}

export type TestContext = {
	test: (name: string, fn: () -> ()) -> (),
	expect: (value: any) -> ExpectResult,
	fail: (message: string) -> (),
	screenshot: (name: string?) -> (),
	plugin: Plugin,
}

return {}
