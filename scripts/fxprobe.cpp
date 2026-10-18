/* fxprobe.cpp - verify builtin effect registration for the YMM4 wine patches
 * Creates each of the 18 newly registered effects, sets property 0,
 * sets a source input, draws it, and reports results. */
#include <windows.h>
#include <d2d1.h>
#include <d2d1_1.h>
#include <d2d1helper.h>
#include <d2d1effects.h>
#include <d2d1effects_2.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <cstdio>

struct fx { const CLSID *id; const char *name; unsigned prop0_size; };

int main(void)
{
    static const fx FX[] = {
        {&CLSID_D2D1ChromaKey,        "ChromaKey",        16},
        {&CLSID_D2D1CrossFade,        "CrossFade",         4},
        {&CLSID_D2D1DistantDiffuse,   "DistantDiffuse",    4},
        {&CLSID_D2D1DistantSpecular,  "DistantSpecular",   4},
        {&CLSID_D2D1EdgeDetection,    "EdgeDetection",     4},
        {&CLSID_D2D1Exposure,         "Exposure",          4},
        {&CLSID_D2D1GammaTransfer,    "GammaTransfer",     4},
        {&CLSID_D2D1HighlightsShadows,"HighlightsShadows", 4},
        {&CLSID_D2D1Invert,           "Invert",            0},
        {&CLSID_D2D1LinearTransfer,   "LinearTransfer",    4},
        {&CLSID_D2D1LuminanceToAlpha, "LuminanceToAlpha",  0},
        {&CLSID_D2D1Morphology,       "Morphology",        4},
        {&CLSID_D2D1PointDiffuse,     "PointDiffuse",     12},
        {&CLSID_D2D1Posterize,        "Posterize",         4},
        {&CLSID_D2D1Sepia,            "Sepia",             4},
        {&CLSID_D2D1Sharpen,          "Sharpen",           4},
        {&CLSID_D2D1Tile,             "Tile",             16},
        {&CLSID_D2D1Tint,             "Tint",             16},
    };

    ID3D11Device *d3d = NULL; ID3D11DeviceContext *ictx = NULL; D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0,
                                   D3D11_SDK_VERSION, &d3d, &fl, &ictx);
    printf("FXPROBE: D3D11CreateDevice hr=0x%08lx\n", (unsigned long)hr);
    if (FAILED(hr)) return 1;

    IDXGIDevice *dxgi = NULL;
    hr = d3d->QueryInterface(__uuidof(IDXGIDevice), (void **)&dxgi);
    if (FAILED(hr)) { printf("FXPROBE: QI IDXGIDevice hr=0x%08lx\n", (unsigned long)hr); return 1; }

    ID2D1Factory1 *factory = NULL;
    hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, __uuidof(ID2D1Factory1), NULL, (void **)&factory);
    if (FAILED(hr)) { printf("FXPROBE: D2D1CreateFactory hr=0x%08lx\n", (unsigned long)hr); return 1; }

    ID2D1Device *d2ddev = NULL;
    hr = factory->CreateDevice(dxgi, &d2ddev);
    if (FAILED(hr)) { printf("FXPROBE: CreateDevice hr=0x%08lx\n", (unsigned long)hr); return 1; }

    ID2D1DeviceContext *dc = NULL;
    hr = d2ddev->CreateDeviceContext(D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &dc);
    if (FAILED(hr)) { printf("FXPROBE: CreateDeviceContext hr=0x%08lx\n", (unsigned long)hr); return 1; }

    D2D1_BITMAP_PROPERTIES1 tbp = D2D1::BitmapProperties1(D2D1_BITMAP_OPTIONS_TARGET,
        D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED));
    ID2D1Bitmap1 *target = NULL;
    hr = dc->CreateBitmap(D2D1::SizeU(256, 256), NULL, 0, &tbp, &target);
    if (FAILED(hr)) { printf("FXPROBE: CreateBitmap(target) hr=0x%08lx\n", (unsigned long)hr); return 1; }
    dc->SetTarget(target);

    D2D1_BITMAP_PROPERTIES1 sbp = D2D1::BitmapProperties1(D2D1_BITMAP_OPTIONS_NONE,
        D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED));
    ID2D1Bitmap1 *src = NULL;
    hr = dc->CreateBitmap(D2D1::SizeU(64, 64), NULL, 0, &sbp, &src);
    if (FAILED(hr)) { printf("FXPROBE: CreateBitmap(src) hr=0x%08lx\n", (unsigned long)hr); return 1; }

    int n_ok = 0, n_fail = 0;
    for (unsigned i = 0; i < sizeof(FX) / sizeof(FX[0]); i++)
    {
        ID2D1Effect *e = NULL;
        hr = dc->CreateEffect(*FX[i].id, &e);
        printf("FXPROBE: %-18s CreateEffect hr=0x%08lx", FX[i].name, (unsigned long)hr);
        if (FAILED(hr)) { printf("  FAIL\n"); n_fail++; continue; }

        HRESULT hr2 = S_OK;
        if (FX[i].prop0_size)
        {
            BYTE buf[16] = {0};
            hr2 = e->SetValue(0, buf, FX[i].prop0_size);
        }
        e->SetInput(0, src);

        dc->BeginDraw();
        dc->DrawImage(e, D2D1::Point2F(10.0f, 10.0f));
        HRESULT hr3 = dc->EndDraw();

        printf("  set0=0x%08lx draw=0x%08lx\n", (unsigned long)hr2, (unsigned long)hr3);
        if (SUCCEEDED(hr2) && SUCCEEDED(hr3)) n_ok++; else n_fail++;
        e->Release();
    }

    printf("FXPROBE: RESULT ok=%d fail=%d\n", n_ok, n_fail);
    return n_fail ? 2 : 0;
}
