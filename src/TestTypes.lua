type ExpectResult = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
}

export type TestContext = {
	test: (name: string, fn: () -> ()) -> (),
	expect: (value: any) -> ExpectResult,
	fail: (message: string) -> (),
	plugin: Plugin,
}

return {}
