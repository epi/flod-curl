/**
Bindings for cURL library.

Authors: $(LINK2 https://github.com/epi, Adrian Matoga)
Copyright: © 2016 Adrian Matoga
License: $(LINK2 https://curl.haxx.se/docs/copyright.html, MIT/X derivate license).
*/
module flod.etc.curl;

import flod.traits : source, Method;

@source!ubyte(Method.push)
private struct CurlReader(alias Context, A...) {
	mixin Context!A;

	import etc.c.curl;
	import std.exception : enforce;
	import std.string : toStringz, format, fromStringz;

	const(char)* url;
	Throwable e;

	this()(in char[] url)
	{
		this.url = url.toStringz();
	}

	private extern(C)
	static size_t mywrite(const(void)* buf, size_t ms, size_t nm, void* obj)
	{
		CurlReader* self = cast(CurlReader*) obj;
		size_t written;
		try {
			written = self.sink.push((cast(const(ubyte)*) buf)[0 .. ms * nm]);
		} catch (Throwable e) {
			self.e = e;
		}
		return written;
	}

	void run()
	{
		CURL* curl = enforce(curl_easy_init(), "Failed to init libcurl");
		curl_easy_setopt(curl, CurlOption.url, url);
		curl_easy_setopt(curl, CurlOption.writefunction, &mywrite);
		curl_easy_setopt(curl, CurlOption.file, &this);
		auto err = curl_easy_perform(curl);
		scope(exit) curl_easy_cleanup(curl);
		if (e)
			throw e;
		if (err == CurlError.write_error) // all good, it's just that sink didn't want more data.
			return;
		enforce(err == CurlError.ok, format("libcurl: (%d) %s", err, fromStringz(curl_easy_strerror(err))));
	}
}

/**
Download the resource pointed to by `url`.

Example:
----
download("http://example.com/")
	.byLine
	.each!writeln;
----
*/
auto download(in char[] url)
{
	import flod.pipeline : pipe;
	return pipe!CurlReader(url);
}

unittest {
	import std.file : write, remove, exists;
	import std.uuid : randomUUID;
	import flod : array, take;
	auto name = "unittest-" ~ randomUUID().toString();
	scope(exit) if (exists(name)) remove(name);
	write(name, new ubyte[1048576]);
	assert(download("file://" ~ name).array() == new ubyte[1048576]);
	assert(download("file://" ~ name).take(313377).array() == new ubyte[313377]);
}
