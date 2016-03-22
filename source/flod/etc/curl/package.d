module flod.etc.curl;

import flod.traits;

@pushSource!ubyte
private struct CurlReader(alias Context, A...) {
	mixin Context!A;

	import etc.c.curl;
	import std.exception : enforce;
	import std.string : toStringz, format, fromStringz;

	const(char)* url;
	Throwable e;

	this()(string url)
	{
		this.url = url.toStringz();
	}

	pragma(msg, __traits(allMembers, typeof(this)));

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
		enforce(err == CurlError.ok, format("libcurl: (%d) %s", err, fromStringz(curl_easy_strerror(err))));
	}
}

auto download(string url)
{
	import flod.pipeline;
	static assert(isPipeline!(typeof(pipe!CurlReader(url))));
	return pipe!CurlReader(url);
}

unittest {
	import std.array : appender;
	import std.file : write, remove;
	import std.uuid : randomUUID;
	import flod : copy;
	auto name = "unittest-" ~ randomUUID().toString();
	write(name, new ubyte[1048576]);
	scope(exit) remove(name);
	auto app = appender!(ubyte[]);
	download("file://" ~ name).copy(app);
	assert(app.data[] == new ubyte[1048576]);
}
